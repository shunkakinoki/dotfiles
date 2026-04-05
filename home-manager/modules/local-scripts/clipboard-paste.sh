#!/usr/bin/env bash

set -euo pipefail

if command -v pbpaste >/dev/null 2>&1; then
  exec pbpaste
fi

if [[ -n ${WAYLAND_DISPLAY:-} ]] && command -v wl-paste >/dev/null 2>&1; then
  exec wl-paste --no-newline
fi

if command -v xclip >/dev/null 2>&1; then
  exec xclip -selection clipboard -o
fi

if command -v xsel >/dev/null 2>&1; then
  exec xsel --clipboard --output
fi

printf 'No clipboard backend available\n' >&2
exit 1
