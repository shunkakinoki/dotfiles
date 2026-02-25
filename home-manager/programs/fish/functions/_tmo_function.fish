function _tmo_function --description "Attach to tmux mobile session"
  if tmux has-session -t mobile 2>/dev/null
    if test -n "$TMUX"
      tmux switch-client -t mobile
    else
      tmux attach-session -t mobile
    end
  else
    tmuxinator start mobile
  end
end
