function _tsw_function --description "Fuzzy-pick any window across all sessions"
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

  set -l selected (tmux list-windows -a -F '#{session_name}:#{window_index}  #{window_name}' 2>/dev/null \
    | fzf --prompt="window> " --height=40% \
          --preview='set t (string split "  " {})[1]; tmux list-panes -t $t -F "#P: #{pane_current_command}  #{pane_current_path}" 2>/dev/null')

  if test -z "$selected"
    return
  end

  set -l target (string split '  ' $selected)[1]   # "session:index"
  set -l parts (string split ':' $target)
  set -l sess $parts[1]
  set -l widx $parts[2]

  if test -n "$TMUX"
    tmux switch-client -t "$sess"
    tmux select-window -t "$sess:$widx"
  else
    tmux attach-session -t "$sess" \; select-window -t "$sess:$widx"
  end
end
