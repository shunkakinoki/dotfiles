function _tss_function --description "Fuzzy-pick or create a tmux session"
  set -l default_sessions primary mobile desktop work

  # Build candidate list: default sessions first, then any extra existing sessions
  set -l existing (tmux list-sessions -F '#S' 2>/dev/null)
  set -l candidates $default_sessions
  for s in $existing
    if not contains $s $default_sessions
      set -a candidates $s
    end
  end

  set -l selected (printf '%s\n' $candidates | fzf \
    --prompt="session> " \
    --height=40% \
    --preview='tmux list-windows -F "#I: #W" -t {} 2>/dev/null' \
    --bind='ctrl-x:execute-silent(tmux kill-session -t {})+abort')

  if test -n "$selected"
    if tmux has-session -t "$selected" 2>/dev/null
      if test -n "$TMUX"
        tmux switch-client -t "$selected"
      else
        tmux attach-session -t "$selected"
      end
    else if test "$selected" = work
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
    else if contains $selected $default_sessions
      tmuxinator start "$selected"
    else
      tmux new-session -d -s "$selected"
      if test -n "$TMUX"
        tmux switch-client -t "$selected"
      else
        tmux attach-session -t "$selected"
      end
    end
  end
end
