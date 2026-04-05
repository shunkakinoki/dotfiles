function _tzo_function --description "Open tmux session named after current Zellij tab"
  if test -z "$ZELLIJ"
    echo "Not inside a Zellij session" >&2
    return 1
  end
  set -l tab_name (zellij action dump-layout 2>/dev/null | grep -oP 'tab name="\K[^"]+(?="[^}]*focus=true)')
  if test -z "$tab_name"
    echo "Could not determine Zellij tab name" >&2
    return 1
  end
  if tmux has-session -t "$tab_name" 2>/dev/null
    tmux attach-session -t "$tab_name"
  else
    tmux new-session -s "$tab_name"
  end
end
