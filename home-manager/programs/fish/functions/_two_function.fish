function _two_function --description "Attach to tmux work session"
  set -l restore (tmux list-keys 2>/dev/null | string match -rg '(/\S+/resurrect/scripts/restore\.sh)')
  set -l restore $restore[1]
  if test -n "$restore"
    tmux run-shell "$restore"
  end

  if tmux has-session -t work 2>/dev/null
    if test -n "$TMUX"
      tmux switch-client -t work
    else
      tmux attach-session -t work
    end
  else
    tmuxinator start work
  end
end
