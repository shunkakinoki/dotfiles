function _tmo_function --description "Attach to tmux mobile session"
  if test -n "$TMUX"
    set -l current (tmux display-message -p '#S' 2>/dev/null)
    if test "$current" = mobile
      return 0
    end
  end

  if not tmux has-session -t mobile 2>/dev/null
    __tmux_bootstrap_default_session mobile
    or return 1
  end

  if test -n "$TMUX"
    tmux switch-client -t mobile
  else
    tmux attach-session -t mobile
  end
end
