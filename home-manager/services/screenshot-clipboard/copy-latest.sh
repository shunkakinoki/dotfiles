#!/usr/bin/env bash

set -euo pipefail

DESKTOP_DIR="$HOME/Desktop"
CLIPBOARD_COPY_IMAGE="$HOME/.local/scripts/clipboard-copy-image"
STATE_FILE="${XDG_STATE_HOME:-$HOME/.local/state}/screenshot-clipboard/last-copied"

if [ ! -x "$CLIPBOARD_COPY_IMAGE" ]; then
  echo "clipboard-copy-image not found at $CLIPBOARD_COPY_IMAGE" >&2
  exit 1
fi

# launchd WatchPaths fires on any Desktop change (including sync clients
# touching the folder), so only a screenshot written in the last few seconds
# counts as a fresh capture. macOS writes a hidden temp file and renames it
# into place, so the visible file is already complete.
shopt -s nullglob
screenshots=("$DESKTOP_DIR"/Screenshot\ *.png "$DESKTOP_DIR"/Screen\ Shot\ *.png)
[ ${#screenshots[@]} -gt 0 ] || exit 0

# One stat call for every file: the Desktop can hold thousands of screenshots.
newest=$(
  {
    stat -c '%Y %n' "${screenshots[@]}" 2>/dev/null ||
      stat -f '%m %N' "${screenshots[@]}"
  } | sort -n | tail -n 1
)
latest_mtime=${newest%% *}
latest=${newest#* }

[ $(($(date +%s) - latest_mtime)) -le 10 ] || exit 0

mkdir -p "$(dirname "$STATE_FILE")"
if [ -f "$STATE_FILE" ] && [ "$(cat "$STATE_FILE")" = "$latest" ]; then
  exit 0
fi

"$CLIPBOARD_COPY_IMAGE" "$latest"
printf '%s' "$latest" >"$STATE_FILE"
