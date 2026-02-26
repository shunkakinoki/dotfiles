function _tsk_function --description "Kill tmux sessions or windows via fzf"
  # Build list: sessions and windows
  set -l items (begin
    tmux list-sessions -F 'session  #{session_name}' 2>/dev/null
    tmux list-windows -a -F 'window   #{session_name}:#{window_index}  #{window_name}' 2>/dev/null
  end)

  set -l selected (printf '%s\n' $items \
    | fzf --prompt="kill> " \
          --height=40% \
          --multi \
          --preview='
            set kind (string split "  " {})[1]
            set target (string split "  " {})[2]
            if test "$kind" = session
              tmux list-windows -F "#I: #W  #{pane_current_path}" -t $target 2>/dev/null
            else
              tmux list-panes -F "#P: #{pane_current_command}  #{pane_current_path}" -t $target 2>/dev/null
            end')

  if test -z "$selected"
    return
  end

  for line in $selected
    set -l kind (string split '  ' $line)[1]
    set -l target (string split '  ' $line)[2]
    if test "$kind" = session
      tmux kill-session -t "$target" 2>/dev/null
    else
      tmux kill-window -t "$target" 2>/dev/null
    end
  end
end
