function _tpo_function --description "Attach to tmux primary session"
  if test -n "$TMUX"
    set -l current (tmux display-message -p '#S' 2>/dev/null)
    if test "$current" = primary
      return 0
    end
  end

  if not tmux has-session -t primary 2>/dev/null
    __tmux_bootstrap_default_session primary
    or return 1
  end

  if test -n "$TMUX"
    tmux switch-client -t primary
  else
    tmux attach-session -t primary
  end
end
