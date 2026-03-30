function _tmo_function --description "Attach to tmux mobile session"
  if tmux has-session -t mobile 2>/dev/null
    if test -n "$TMUX"
      tmux detach-client
    end
    tmux attach-session -t mobile
  else
    tmuxinator start mobile
  end
end
