#!/usr/bin/env bash

set -euo pipefail

DESKTOP_DIR="$HOME/Desktop"
CLIPBOARD_COPY_IMAGE="$HOME/.local/scripts/clipboard-copy-image"

if ! command -v fswatch >/dev/null 2>&1; then
  echo "fswatch not found; screenshot-clipboard agent disabled" >&2
  exit 1
fi

if [ ! -x "$CLIPBOARD_COPY_IMAGE" ]; then
  echo "clipboard-copy-image not found at $CLIPBOARD_COPY_IMAGE" >&2
  exit 1
fi

mkdir -p "$DESKTOP_DIR"

echo "Watching $DESKTOP_DIR for screenshots..."

file_size() {
  stat -c %s "$1" 2>/dev/null || stat -f %z "$1" 2>/dev/null
}

file_mtime() {
  stat -c %Y "$1" 2>/dev/null || stat -f %m "$1" 2>/dev/null
}

wait_until_stable() {
  previous_size=""
  for _ in 1 2 3 4 5 6 7 8 9 10; do
    [ -f "$1" ] || {
      sleep 0.1
      continue
    }

    size=$(file_size "$1" || true)
    if [ -n "$size" ] && [ "$size" != "0" ] && [ "$size" = "$previous_size" ]; then
      return 0
    fi

    previous_size=$size
    sleep 0.1
  done
}

latest_recent_screenshot() {
  now=$(date +%s)
  newest_path=$(
    /bin/ls -t "$DESKTOP_DIR"/Screenshot\ *.png "$DESKTOP_DIR"/Screen\ Shot\ *.png "$DESKTOP_DIR"/*_hyprshot.png 2>/dev/null |
      /usr/bin/head -n 1 || true
  )
  [ -n "$newest_path" ] || return 1

  mtime=$(file_mtime "$newest_path" || true)
  [ -n "$mtime" ] || return 1

  age=$((now - mtime))
  [ "$age" -le 15 ] || return 1
  printf '%s\n' "$newest_path"
}

# Screenshots are written atomically (macOS via rename, hyprshot via mv from
# a temp path), so fswatch reports the final path once writing has finished.
# fswatch on macOS uses FSEvents which is always recursive, so the patterns
# are anchored to "$DESKTOP_DIR/" to ignore screenshots inside subfolders
# (e.g. project directories) and only react to fresh top-level captures.
# Patterns:
#   - "Screenshot ..." / "Screen Shot ..." : macOS defaults (current / legacy)
#   - "*_hyprshot.png"                     : hyprshot default name on Linux
#     (HYPRSHOT_DIR is set to $HOME/Desktop in config/hyprland/hyprland.conf)
# FSEvents can coalesce rapid captures into a directory-level event. For every
# screenshot-ish event, wait briefly for adjacent burst captures and then copy
# the newest recent screenshot so the clipboard ends on the last capture.
fswatch --event=Created --event=MovedTo --event=Renamed -0 "$DESKTOP_DIR" |
  while IFS= read -r -d '' path; do
    case "$path" in
    "$DESKTOP_DIR" | \
      "$DESKTOP_DIR/" | \
    "$DESKTOP_DIR/Screenshot "*.png | \
      "$DESKTOP_DIR/Screen Shot "*.png | \
      "$DESKTOP_DIR/"*_hyprshot.png)
      sleep 0.2
      screenshot=$(latest_recent_screenshot || true)
      [ -n "$screenshot" ] || continue
      wait_until_stable "$screenshot"
      "$CLIPBOARD_COPY_IMAGE" "$screenshot" || true
      ;;
    esac
  done
