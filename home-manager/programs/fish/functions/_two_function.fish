function _two_function --description "Attach to tmux work session"
  if tmux has-session -t work 2>/dev/null
    if test -n "$TMUX"
      tmux switch-client -t work
    else
      tmux attach-session -t work
    end
    return
  end

  # No work session — try resurrect restore
  if test -f ~/.tmux/resurrect/last
    # Start a detached session so the server is running
    tmux new-session -d -s _restore 2>/dev/null
    set -l restore (tmux list-keys 2>/dev/null | string match -rg '(/\S+/resurrect/scripts/restore\.sh)')
    set -l restore $restore[1]
    if test -n "$restore"
      tmux run-shell "$restore"
      sleep 1
    end
    # Clean up temp session if restore created work
    if tmux has-session -t work 2>/dev/null
      tmux kill-session -t _restore 2>/dev/null
      tmux attach-session -t work
      return
    end
    tmux kill-session -t _restore 2>/dev/null
  end

  # Fallback to tmuxinator
  tmuxinator start work
end
