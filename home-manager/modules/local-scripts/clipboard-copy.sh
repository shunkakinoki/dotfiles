#!/usr/bin/env bash

set -euo pipefail

if command -v pbcopy >/dev/null 2>&1; then
  exec pbcopy
fi

if [[ -n "${WAYLAND_DISPLAY:-}" ]] && command -v wl-copy >/dev/null 2>&1; then
  exec wl-copy
fi

if command -v xclip >/dev/null 2>&1; then
  exec xclip -selection clipboard
fi

if command -v xsel >/dev/null 2>&1; then
  exec xsel --clipboard --input
fi

printf 'No clipboard backend available\n' >&2
exit 1
