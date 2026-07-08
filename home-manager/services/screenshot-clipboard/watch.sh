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

# fswatch event filters are backend-specific; on macOS FSEvents can report
# screenshot writes with combined flags that do not pass --event filters. Watch
# all events there and keep the stable filename filtering here instead.
#
# On Linux (inotify) watching all events is a feedback loop: clipboard-copy-image
# reads the screenshot to pipe it into wl-copy, the read itself emits new events
# on the same path, and the copy repeats forever, clobbering every clipboard
# write system-wide. CloseWrite fires once per completed write and never on
# reads. Renames are reported at directory level by inotify here either way, so
# the filter loses nothing: hyprshot/grim write the file in place.
fswatch_args=()
if [ "$(uname -s)" = "Linux" ]; then
  fswatch_args=(--event CloseWrite)
fi

# fswatch on macOS uses FSEvents which is always recursive, so the patterns are
# anchored to "$DESKTOP_DIR/" to ignore screenshots inside subfolders (e.g.
# project directories) and only react to fresh top-level captures.
# Patterns:
#   - "Screenshot ..." / "Screen Shot ..." : macOS defaults (current / legacy)
#   - "*_hyprshot.png"                     : hyprshot default name on Linux
#     (HYPRSHOT_DIR is set to $HOME/Desktop in config/hyprland/hyprland.conf)
fswatch -0 "${fswatch_args[@]}" "$DESKTOP_DIR" |
  while IFS= read -r -d '' path; do
    case "$path" in
    "$DESKTOP_DIR/Screenshot "*.png | \
      "$DESKTOP_DIR/Screen Shot "*.png | \
      "$DESKTOP_DIR/"*_hyprshot.png)
      wait_until_stable "$path"
      "$CLIPBOARD_COPY_IMAGE" "$path" || true
      ;;
    esac
  done
