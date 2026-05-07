function _tdo_function --description "Attach to tmux desktop session"
  if test -n "$TMUX"
    set -l current (tmux display-message -p '#S' 2>/dev/null)
    if test "$current" = desktop
      return 0
    end
  end

  if not tmux has-session -t desktop 2>/dev/null
    __tmux_bootstrap_default_session desktop
    or return 1
  end

  if test -n "$TMUX"
    tmux switch-client -t desktop
  else
    tmux attach-session -t desktop
  end
end
