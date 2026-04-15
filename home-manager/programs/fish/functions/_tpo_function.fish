if not functions -q __tmux_bootstrap_default_session
  source (status dirname)/__tmux_bootstrap_default_session.fish
end

function _tpo_function --description "Attach to tmux primary session"
  if tmux has-session -t primary 2>/dev/null
    if test -n "$TMUX"
      tmux detach-client
    end
    tmux attach-session -t primary
  else
    __tmux_bootstrap_default_session primary
    or return 1

    if test -n "$TMUX"
      tmux switch-client -t primary
    else
      tmux attach-session -t primary
    end
  end
end
