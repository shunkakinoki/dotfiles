function _tsh_function --description "Search tmux session history log or pane contents"
  set -l log ~/.local/share/tmux/session-history.log
  set -l pane_dir ~/.local/share/tmux/panes
  set -l archive_dir ~/.local/share/tmux/archive

  # With argument(s): search stored pane content files (live + archived)
  if test (count $argv) -gt 0
    if not test -d "$pane_dir"
      echo "No pane content store found at $pane_dir"
      return
    end

    set -l query (string join ' ' $argv)
    set -l selected (rg -l -- "$query" "$pane_dir" "$archive_dir" 2>/dev/null \
      | fzf --prompt="pane-search> " \
            --height=40% \
            --preview="rg -n -- '$query' {} 2>/dev/null | head -80" \
            --preview-window=right:60%)

    if test -z "$selected"
      return
    end

    # work--0--0.txt or work--0--0--20260226-103000.txt → sess=work, widx=0
    set -l fname (string replace -r '.*/' '' "$selected" \
      | string replace -r '--\d{8}-\d{6}\.txt$' '' \
      | string replace '.txt' '')
    set -l parts (string split -- '--' $fname)
    set -l sess $parts[1]
    set -l widx $parts[2]

    if not tmux has-session -t "$sess" 2>/dev/null
      echo "Session '$sess' no longer exists (archived pane — content shown above in preview)"
      return
    end

    if test -n "$TMUX"
      tmux switch-client -t "$sess"
      tmux select-window -t "$sess:$widx" 2>/dev/null
    else
      tmux attach-session -t "$sess" \; select-window -t "$sess:$widx"
    end
    return
  end

  # No argument: fzf over the history log (session/window/path metadata)
  if not test -f "$log"
    echo "No session history found at $log"
    return
  end

  set -l selected (cat "$log" | fzf \
    --prompt="session-history> " \
    --height=40% \
    --tac \
    --no-sort \
    --preview='echo {}')

  if test -z "$selected"
    return
  end

  set -l target (string split '  ' $selected)[2]
  set -l parts (string split ':' $target)
  set -l sess $parts[1]
  set -l widx $parts[2]

  if not tmux has-session -t "$sess" 2>/dev/null
    echo "Session '$sess' no longer exists"
    return
  end

  if test -n "$TMUX"
    tmux switch-client -t "$sess"
    tmux select-window -t "$sess:$widx" 2>/dev/null
  else
    tmux attach-session -t "$sess" \; select-window -t "$sess:$widx"
  end
end
