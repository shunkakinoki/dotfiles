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

is_ssh() {
  [[ -n ${SSH_TTY:-} || -n ${SSH_CONNECTION:-} || -n ${SSH_CLIENT:-} ]]
}

image_mime() {
  local lower
  lower=$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')
  case $lower in
  *.jpg | *.jpeg) printf 'image/jpeg' ;;
  *.gif) printf 'image/gif' ;;
  *.webp) printf 'image/webp' ;;
  *.tif | *.tiff) printf 'image/tiff' ;;
  *.bmp) printf 'image/bmp' ;;
  *) printf 'image/png' ;;
  esac
}

# OSC 5522 (Kitty clipboard protocol) carries typed image bytes through the
# PTY to the local terminal. Ghostty parses this; write support is landing
# on tip. Remote native clipboards are the wrong destination over SSH.
if is_ssh; then
  mime=$(image_mime "$file")
  mime_b64=$(printf '%s' "$mime" | base64 | tr -d '\n')
  data_b64=$(base64 <"$file" | tr -d '\n')
  # OSC 5522 terminator is ESC + backslash. SC1003 misreads the \\ in quotes.
  # shellcheck disable=SC1003
  seq=$(printf '\033]5522;type=write:mime=%s;%s\033\\' "$mime_b64" "$data_b64")
  printf '%s' "$seq"
  if [[ -n ${SSH_TTY:-} && -w ${SSH_TTY} ]]; then
    printf '%s' "$seq" >"$SSH_TTY" 2>/dev/null || true
  fi
  exit 0
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
