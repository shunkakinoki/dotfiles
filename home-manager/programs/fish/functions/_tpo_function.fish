function _tpo_function --description "Attach to tmux primary session"
  if tmux has-session -t primary 2>/dev/null
    if test -n "$TMUX"
      tmux detach-client
    end
    tmux attach-session -t primary
  else
    tmuxinator start primary
  end
end
