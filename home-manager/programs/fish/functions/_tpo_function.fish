function _tpo_function --description "Attach to tmux primary session"
  if tmux has-session -t primary 2>/dev/null
    if test -n "$TMUX"
      tmux switch-client -t primary
    else
      tmux attach-session -t primary
    end
  else
    tmuxinator start primary
  end
end
