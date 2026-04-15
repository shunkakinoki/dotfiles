function _two_function --description "Attach to tmux work session"
  if tmux has-session -t work 2>/dev/null
    if test -n "$TMUX"
      tmux switch-client -t work
    else
      tmux attach-session -t work
    end
    return
  end

  set -l restore (tmux list-keys 2>/dev/null | string match -rg '(/\S+/resurrect/scripts/restore\.sh)')
  set -l restore $restore[1]
  set -l bootstrapped 0

  # Start a server if needed so we can invoke the restore script.
  if not tmux list-sessions 2>/dev/null | grep -q .
    tmux new-session -d -s _bootstrap
    set bootstrapped 1
  end

  if test -n "$restore"
    tmux run-shell "$restore"
    # Give tmux-resurrect a moment to recreate the work session.
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

  # Restore didn't produce work — fall back to tmuxinator.
  if test -n "$TMUX"
    TMUX= tmuxinator start work --no-attach 2>/dev/null
    tmux switch-client -t work
  else
    tmuxinator start work
  end
end
