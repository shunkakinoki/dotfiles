if not functions -q __tmux_bootstrap_default_session
  source (status dirname)/__tmux_bootstrap_default_session.fish
end

function _tdo_function --description "Attach to tmux desktop session"
  if tmux has-session -t desktop 2>/dev/null
    if test -n "$TMUX"
      tmux detach-client
    end
    tmux attach-session -t desktop
  else
    __tmux_bootstrap_default_session desktop
    or return 1

    if test -n "$TMUX"
      tmux switch-client -t desktop
    else
      tmux attach-session -t desktop
    end
  end
end
