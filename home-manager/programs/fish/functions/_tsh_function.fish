function _tsh_function --description "Search tmux pane contents (live + archived)"
  set -l pane_dir ~/.local/share/tmux/panes
  set -l archive_dir ~/.local/share/tmux/archive

  # Default: fzf over pane content files, optional query pre-fills search
  if not test -d "$pane_dir"
    echo "No pane content store found at $pane_dir"
    return
  end

  set -l query (string join ' ' $argv)
  set -l selected (rg -l -- "$query" "$pane_dir" "$archive_dir" 2>/dev/null \
    | fzf --prompt="pane-search> " \
          --height=40% \
          --query="$query" \
          --preview="rg -n -- '$query' {} 2>/dev/null | head -80" \
          --preview-window=right:60%)

  if test -z "$selected"
    return
  end

  # work--0--0.txt or work--0--0--20260226-103000.txt → sess=work, widx=0
  set -l fname (string replace -r '.*/' '' "$selected" \
    | string replace -r '(\-\-[0-9]{8}-[0-9]{6})?\.txt$' '')
  set -l parts (string split -- '--' $fname)
  set -l sess $parts[1]
  set -l widx $parts[2]

  # Archived file → display with bat; live pane → switch to session
  if string match -q "$archive_dir/*" "$selected"
    bat --style=plain "$selected" 2>/dev/null; or less "$selected"
    return
  end

  if test -n "$TMUX"
    tmux switch-client -t "$sess"
    tmux select-window -t "$sess:$widx" 2>/dev/null
  else
    tmux attach-session -t "$sess" \; select-window -t "$sess:$widx"
  end
end
