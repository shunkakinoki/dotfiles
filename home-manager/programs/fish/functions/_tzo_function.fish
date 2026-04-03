function _tzo_function --description "Open tmux session named after current Zellij tab"
  if test -z "$ZELLIJ_TAB_NAME"
    echo "Not inside a Zellij tab" >&2
    return 1
  end
  if tmux has-session -t "$ZELLIJ_TAB_NAME" 2>/dev/null
    tmux attach-session -t "$ZELLIJ_TAB_NAME"
  else
    tmux new-session -s "$ZELLIJ_TAB_NAME"
  end
end
