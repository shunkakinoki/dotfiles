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

# macOS writes screenshots atomically via a rename, so fswatch reports the
# final path once writing has completed. The case glob matches both the
# current default ("Screenshot ...") and the legacy ("Screen Shot ...")
# filenames to keep working if locale or macOS version changes them.
fswatch --event=Created --event=MovedTo --event=Renamed -0 "$DESKTOP_DIR" |
  while IFS= read -r -d '' path; do
    case "$path" in
    *"/Screenshot "*.png | *"/Screen Shot "*.png)
      "$CLIPBOARD_COPY_IMAGE" "$path" || true
      ;;
    esac
  done
