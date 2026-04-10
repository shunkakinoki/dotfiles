function _two_function --description "Attach to tmux work session"
  if tmux has-session -t work 2>/dev/null
    if test -n "$TMUX"
      tmux switch-client -t work
    else
      tmux attach-session -t work
    end
    return
  end

  # No tmux server or no work session — start server and let continuum restore
  if not tmux list-sessions 2>/dev/null | grep -q .
    # No server running — start one; continuum will auto-restore work session
    tmux new-session -d -s _bootstrap
    # Give continuum a moment to restore
    sleep 3
    if tmux has-session -t work 2>/dev/null
      tmux kill-session -t _bootstrap 2>/dev/null
      if test -n "$TMUX"
        tmux switch-client -t work
      else
        tmux attach-session -t work
      end
      return
    end
    tmux kill-session -t _bootstrap 2>/dev/null
  end

  # Continuum didn't restore work — fall back to tmuxinator
  if test -n "$TMUX"
    TMUX= tmuxinator start work --no-attach 2>/dev/null
    tmux switch-client -t work
  else
    tmuxinator start work
  end
end
