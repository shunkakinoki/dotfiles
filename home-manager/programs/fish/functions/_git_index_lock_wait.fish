function _git_index_lock_wait --description "Wait for .git/index.lock to clear; remove it only when nothing holds it"
  set -l max_wait 30
  if test (count $argv) -ge 1
    set max_wait $argv[1]
  end

  set -l lock (git rev-parse --git-path index.lock 2>/dev/null)
  if test -z "$lock"; or not test -e "$lock"
    return 0
  end

  # A live writer finishes within seconds even on a large index, so poll
  # briefly before deciding anything.
  set -l waited 0
  while test -e "$lock"; and test $waited -lt $max_wait
    sleep 1
    set waited (math $waited + 1)
  end
  if not test -e "$lock"
    return 0
  end

  # Git never records the lock owner, so "stale" is inferred: no process has
  # the file open and no git process runs inside this repository. A lock that
  # outlives its writer is left behind only by a killed process (SIGKILL skips
  # git's cleanup handler), which is the case worth reaping automatically.
  set -l repo (git rev-parse --show-toplevel 2>/dev/null)
  set -l holders
  if type -q lsof
    set holders (lsof -t -- "$lock" 2>/dev/null)
    if test (count $holders) -eq 0
      set -l pid
      for line in (lsof -a -c git -d cwd -F pn 2>/dev/null)
        switch $line
          case 'p*'
            set pid (string sub -s 2 -- $line)
          case 'n*'
            if string match -qr '^n'(string escape --style=regex -- $repo)'(/|$)' -- $line
              set -a holders $pid
            end
        end
      end
    end
  else
    set holders (pgrep -x git)
  end

  if test (count $holders) -eq 0
    set -l mtime (stat -f %m "$lock" 2>/dev/null; or stat -c %Y "$lock" 2>/dev/null)
    set -l age (math (date +%s) - $mtime)
    echo "git: removing stale index.lock (age $age s, no holder)" >&2
    rm -f -- "$lock"
    return 0
  end

  echo "git: index.lock is held by a running process; wait or stop it first:" >&2
  ps -o pid=,etime=,command= -p (string join , $holders) 2>/dev/null | head -5 >&2
  return 1
end
