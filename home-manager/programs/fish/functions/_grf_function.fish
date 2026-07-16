function _grf_function --description "Refresh to origin default branch every 3 minutes"
  set -l interval 180
  set -l once 0

  for arg in $argv
    switch $arg
      case --once
        set once 1
      case '*'
        if string match -qr '^[0-9]+$' -- $arg
          set interval $arg
        else
          echo "grf: unknown argument: $arg" >&2
          echo "usage: grf [--once] [interval_seconds]" >&2
          return 2
        end
    end
  end

  if test $once -eq 0
    echo "grf: refreshing to origin default branch every {$interval}s (Ctrl-C to stop)"
  end

  while true
    # Determine the default branch (e.g., main or master) from origin/HEAD
    set -l default_branch (git symbolic-ref refs/remotes/origin/HEAD | sed 's@^refs/remotes/origin/@@')
    set -l ts (date '+%Y-%m-%d %H:%M:%S')
    set -l ok 0

    if not git fetch origin $default_branch
      echo "[$ts] grf: fetch failed, will retry" >&2
    else
      set -l current_branch (git rev-parse --abbrev-ref HEAD)
      set -l dirty 0
      if not git diff --quiet; or not git diff --cached --quiet
        set dirty 1
      end

      if test "$current_branch" = "$default_branch"; and test $dirty -eq 0
        # On default branch, clean tree: pull if fast-forwardable (no conflicts)
        if git merge-base --is-ancestor HEAD origin/$default_branch
          echo "[$ts] grf: pull --ff-only origin/$default_branch"
          if git pull --ff-only origin $default_branch
            set ok 1
            echo "[$ts] grf: ok (pulled origin/$default_branch)"
          else
            echo "[$ts] grf: pull failed, will retry" >&2
          end
        else
          # Diverged local history: hard reset to remote
          echo "[$ts] grf: diverged; hard reset origin/$default_branch"
          if git branch --set-upstream-to=origin/$default_branch $default_branch
            and git reset --hard origin/$default_branch
            set ok 1
            echo "[$ts] grf: ok (reset origin/$default_branch)"
          else
            echo "[$ts] grf: reset failed, will retry" >&2
          end
        end
      else if test $dirty -eq 1
        echo "[$ts] grf: dirty working tree on $current_branch, skipping" >&2
      else
        # Not on default branch: checkout and hard reset
        echo "[$ts] grf: checkout + hard reset origin/$default_branch"
        if git checkout $default_branch
          and git branch --set-upstream-to=origin/$default_branch $default_branch
          and git reset --hard origin/$default_branch
          set ok 1
          echo "[$ts] grf: ok (reset origin/$default_branch)"
        else
          echo "[$ts] grf: reset failed, will retry" >&2
        end
      end
    end

    if test $once -eq 1
      test $ok -eq 1
      return $status
    end

    sleep $interval
  end
end
