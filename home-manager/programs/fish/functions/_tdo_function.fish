function _tdo_function --description "Attach to tmux desktop session"
  if tmux has-session -t desktop 2>/dev/null
    if test -n "$TMUX"
      tmux switch-client -t desktop
    else
      tmux attach-session -t desktop
    end
  else
    tmuxinator start desktop
  end
end
