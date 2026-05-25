#!/usr/bin/env bash

set -eu

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
# Patterns:
#   - "Screenshot ..." / "Screen Shot ..." : macOS defaults (current / legacy)
#   - "*_hyprshot.png"                     : hyprshot default name on Linux
#   - "swappy-*.png"                       : grim | swappy default name
fswatch --event=Created --event=MovedTo --event=Renamed -0 "$DESKTOP_DIR" |
  while IFS= read -r -d '' path; do
    case "$path" in
    *"/Screenshot "*.png | *"/Screen Shot "*.png | *_hyprshot.png | *"/swappy-"*.png)
      "$CLIPBOARD_COPY_IMAGE" "$path" || true
      ;;
    esac
  done
