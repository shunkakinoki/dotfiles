function _two_function --description "Attach to tmux work session"
  if tmux has-session -t work 2>/dev/null
    if test -n "$TMUX"
      tmux switch-client -t work
    else
      tmux attach-session -t work
    end
    return
  end

  set -l bootstrapped 0

  # Start a server if needed so plugins load and resurrect becomes available.
  if not tmux list-sessions 2>/dev/null | grep -q .
    tmux new-session -d -s _bootstrap
    set bootstrapped 1
  end

  # Resolve restore script after server is running (plugins are loaded).
  set -l restore (tmux show-options -gv @resurrect-restore-script-path 2>/dev/null)
  if test -z "$restore"
    set restore (tmux list-keys 2>/dev/null | string match -rg '(/\S+/resurrect/scripts/restore\.sh)')
    set restore $restore[1]
  end

  if test -n "$restore"
    tmux run-shell "$restore"
    for _i in (seq 1 50)
      if tmux has-session -t work 2>/dev/null
        if test $bootstrapped -eq 1
          tmux kill-session -t _bootstrap 2>/dev/null
        end
        if test -n "$TMUX"
          tmux switch-client -t work
        else
          tmux attach-session -t work
        end
        return
      end
      sleep 0.1
    end
  end

  if test $bootstrapped -eq 1
    tmux kill-session -t _bootstrap 2>/dev/null
  end

  __tmux_bootstrap_default_session work
  or return 1

  if test -n "$TMUX"
    tmux switch-client -t work
  else
    tmux attach-session -t work
  end
end
