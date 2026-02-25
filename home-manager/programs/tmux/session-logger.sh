#!/usr/bin/env sh
mkdir -p ~/.local/share/tmux/panes
mkdir -p ~/.local/share/tmux/archive
LOG=~/.local/share/tmux/session-history.log
PANE_DIR=~/.local/share/tmux/panes
ARCHIVE_DIR=~/.local/share/tmux/archive

while true; do
  sleep 30

  # Append window metadata
  tmux list-windows -a \
    -F "$(date +%Y-%m-%dT%H:%M:%S)  #{session_name}:#{window_index}  #{window_name}  #{pane_current_path}" \
    >> "$LOG" 2>/dev/null

  # Rotate existing live snapshots to .old
  for f in "$PANE_DIR"/*.txt; do
    [ -f "$f" ] && mv "$f" "${f%.txt}.old"
  done

  # Recapture all currently live panes
  tmux list-panes -a -F "#{session_name} #{window_index} #{pane_index} #{pane_id}" \
    2>/dev/null | while IFS= read -r line; do
      sess=$(printf '%s' "$line" | cut -d' ' -f1)
      widx=$(printf '%s' "$line" | cut -d' ' -f2)
      pidx=$(printf '%s' "$line" | cut -d' ' -f3)
      pane_id=$(printf '%s' "$line" | cut -d' ' -f4)
      tmux capture-pane -pt "$pane_id" -S - 2>/dev/null \
        > "$PANE_DIR/$sess--$widx--$pidx.txt"
    done

  # For each .old: if a live .txt exists → pane survived → delete .old
  #                if no live .txt  → pane closed  → archive with timestamp
  ts=$(date +%Y%m%d-%H%M%S)
  for old in "$PANE_DIR"/*.old; do
    [ -f "$old" ] || continue
    base=$(basename "${old%.old}")
    if [ -f "$PANE_DIR/$base.txt" ]; then
      rm -f "$old"
    else
      mv "$old" "$ARCHIVE_DIR/${base}--${ts}.txt"
    fi
  done
done
