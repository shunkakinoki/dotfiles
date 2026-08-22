#!/usr/bin/env bash

set -euo pipefail

if [[ $# -ne 1 ]]; then
  printf 'usage: clipboard-copy-file FILE\n' >&2
  exit 2
fi

file=$1

if [[ ! -e $file ]]; then
  printf 'clipboard-copy-file: file not found: %s\n' "$file" >&2
  exit 1
fi

is_ssh() {
  [[ -n ${SSH_TTY:-} || -n ${SSH_CONNECTION:-} || -n ${SSH_CLIENT:-} ]]
}

# Over SSH the remote native clipboard is the wrong destination. Text files
# ride OSC 52 via clipboard-copy; binary files use OSC 5522 so Kitty/Ghostty
# can place typed bytes on the local clipboard.
is_binary() {
  local orig stripped
  orig=$(wc -c <"$1" | tr -d ' ')
  stripped=$(tr -d '\0' <"$1" | wc -c | tr -d ' ')
  [[ $orig != "$stripped" ]]
}

if is_ssh; then
  if ! is_binary "$file"; then
    here=$(dirname "$0")
    if [[ -x $here/clipboard-copy ]]; then
      exec "$here/clipboard-copy" <"$file"
    fi
    if [[ -f $here/clipboard-copy.sh ]]; then
      exec bash "$here/clipboard-copy.sh" <"$file"
    fi
    exec clipboard-copy <"$file"
  fi
  mime=application/octet-stream
  mime_b64=$(printf '%s' "$mime" | base64 | tr -d '\n')
  data_b64=$(base64 <"$file" | tr -d '\n')
  # OSC 5522 terminator is ESC + backslash. SC1003 misreads the \\ in quotes.
  # shellcheck disable=SC1003
  seq=$(printf '\033]5522;type=write:mime=%s;%s\033\\' "$mime_b64" "$data_b64")
  printf '%s' "$seq"
  exit 0
fi

if command -v osascript >/dev/null 2>&1; then
  osascript \
    -e 'on run {f}' \
    -e 'set the clipboard to POSIX file f' \
    -e 'end run' \
    "$file"
  exit 0
fi

abs=$file
if command -v realpath >/dev/null 2>&1; then
  abs=$(realpath "$file")
elif [[ $file != /* ]]; then
  abs="$PWD/$file"
fi
uri=file://$abs

if [[ -n ${WAYLAND_DISPLAY:-} ]] && command -v wl-copy >/dev/null 2>&1; then
  printf '%s\n' "$uri" | wl-copy --type text/uri-list
  exit 0
fi

if command -v xclip >/dev/null 2>&1; then
  printf '%s\n' "$uri" | xclip -selection clipboard -t text/uri-list
  exit 0
fi

printf 'No file clipboard backend available\n' >&2
exit 1
