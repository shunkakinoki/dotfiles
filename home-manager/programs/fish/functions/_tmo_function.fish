if not functions -q __tmux_bootstrap_default_session
  source (status dirname)/__tmux_bootstrap_default_session.fish
end

function _tmo_function --description "Attach to tmux mobile session"
  if tmux has-session -t mobile 2>/dev/null
    if test -n "$TMUX"
      tmux detach-client
    end
    tmux attach-session -t mobile
  else
    __tmux_bootstrap_default_session mobile
    or return 1

    if test -n "$TMUX"
      tmux switch-client -t mobile
    else
      tmux attach-session -t mobile
    end
  end
end
