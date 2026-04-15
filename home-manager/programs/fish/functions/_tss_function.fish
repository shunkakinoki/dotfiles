function _tss_function --description "Fuzzy-pick or create a tmux session"
  if not functions -q _tpo_function
    source (status dirname)/_tpo_function.fish
  end
  if not functions -q _tmo_function
    source (status dirname)/_tmo_function.fish
  end
  if not functions -q _tdo_function
    source (status dirname)/_tdo_function.fish
  end
  if not functions -q _two_function
    source (status dirname)/_two_function.fish
  end

  set -l log ~/.local/share/tmux/session-history.log

  # --log: browse session/window metadata log
  if test (count $argv) -gt 0 -a "$argv[1]" = --log
    if not test -f "$log"
      echo "No session history found at $log"
      return
    end

    set -l selected (cat "$log" | fzf \
      --prompt="session-history> " \
      --height=40% \
      --tac \
      --no-sort \
      --preview='echo {}')

    if test -z "$selected"
      return
    end

    set -l target (string split '  ' $selected)[2]
    set -l parts (string split ':' $target)
    set -l sess $parts[1]
    set -l widx $parts[2]

    if not tmux has-session -t "$sess" 2>/dev/null
      echo "Session '$sess' no longer exists"
      return
    end

    if test -n "$TMUX"
      tmux switch-client -t "$sess"
      tmux select-window -t "$sess:$widx" 2>/dev/null
    else
      tmux attach-session -t "$sess" \; select-window -t "$sess:$widx"
    end
    return
  end

  set -l default_sessions primary mobile desktop work

  # Build candidate list: default sessions first, then any extra existing sessions
  set -l existing (tmux list-sessions -F '#S' 2>/dev/null)
  set -l candidates $default_sessions
  for s in $existing
    if not contains $s $default_sessions
      set -a candidates $s
    end
  end

  set -l selected (printf '%s\n' $candidates | fzf \
    --prompt="session> " \
    --height=40% \
    --preview='tmux list-windows -F "#I: #W" -t {} 2>/dev/null' \
    --bind='ctrl-x:execute-silent(tmux kill-session -t {})+abort')

  if test -n "$selected"
    if tmux has-session -t "$selected" 2>/dev/null
      if test -n "$TMUX"
        tmux switch-client -t "$selected"
      else
        tmux attach-session -t "$selected"
      end
    else if test "$selected" = work
      _two_function
    else if contains $selected $default_sessions
      switch $selected
        case primary
          _tpo_function
        case mobile
          _tmo_function
        case desktop
          _tdo_function
      end
    else
      tmux new-session -d -s "$selected"
      if test -n "$TMUX"
        tmux switch-client -t "$selected"
      else
        tmux attach-session -t "$selected"
      end
    end
  end
end
