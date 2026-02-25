function _tsw_function --description "Fuzzy-pick any window across all sessions"
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
