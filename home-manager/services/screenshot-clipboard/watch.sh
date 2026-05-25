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

# Screenshots are written atomically (macOS via rename, hyprshot via mv from
# a temp path), so fswatch reports the final path once writing has finished.
# fswatch on macOS uses FSEvents which is always recursive, so the patterns
# are anchored to "$DESKTOP_DIR/" to ignore screenshots inside subfolders
# (e.g. project directories) and only react to fresh top-level captures.
# Patterns:
#   - "Screenshot ..." / "Screen Shot ..." : macOS defaults (current / legacy)
#   - "*_hyprshot.png"                     : hyprshot default name on Linux
#   - "swappy-*.png"                       : grim | swappy default name
fswatch --event=Created --event=MovedTo --event=Renamed -0 "$DESKTOP_DIR" |
  while IFS= read -r -d '' path; do
    case "$path" in
    "$DESKTOP_DIR/Screenshot "*.png | \
      "$DESKTOP_DIR/Screen Shot "*.png | \
      "$DESKTOP_DIR/"*_hyprshot.png | \
      "$DESKTOP_DIR/swappy-"*.png)
      "$CLIPBOARD_COPY_IMAGE" "$path" || true
      ;;
    esac
  done
