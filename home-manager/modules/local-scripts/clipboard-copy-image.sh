#!/usr/bin/env bash

set -euo pipefail

if [[ $# -ne 1 ]]; then
  printf 'usage: clipboard-copy-image FILE\n' >&2
  exit 2
fi

file=$1

if [[ ! -f $file ]]; then
  printf 'clipboard-copy-image: file not found: %s\n' "$file" >&2
  exit 1
fi

# macOS: AppleScript reads the file as «class PNGf» so receivers paste it as
# an image. Piping PNG bytes through pbcopy would store them as text and
# break image paste in Slack, Messages, browsers, etc. The path is passed as
# a positional arg to a `run` handler so no shell interpolation reaches the
# AppleScript source - this avoids quote/backslash/$(...) injection.
if command -v osascript >/dev/null 2>&1; then
  osascript \
    -e 'on run {f}' \
    -e 'set the clipboard to (read (POSIX file f) as «class PNGf»)' \
    -e 'end run' \
    "$file"
  exit 0
fi

if [[ -n ${WAYLAND_DISPLAY:-} ]] && command -v wl-copy >/dev/null 2>&1; then
  wl-copy --type image/png <"$file"
  exit 0
fi

if command -v xclip >/dev/null 2>&1; then
  xclip -selection clipboard -t image/png -i "$file"
  exit 0
fi

printf 'No image clipboard backend available\n' >&2
exit 1
