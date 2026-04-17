#!/usr/bin/env bash

set -euo pipefail

if [[ -n ${WAYLAND_DISPLAY:-} ]] && command -v wl-copy >/dev/null 2>&1; then
  exec wl-copy
fi

if command -v pbcopy >/dev/null 2>&1; then
  exec pbcopy
fi

if command -v xclip >/dev/null 2>&1; then
  exec xclip -selection clipboard
fi

if command -v xsel >/dev/null 2>&1; then
  exec xsel --clipboard --input
fi

# OSC 52 fallback: works over SSH if the terminal supports it
# (ghostty, iTerm2, kitty, alacritty, tmux, etc.)
if [[ -t 1 ]] || [[ -n ${TMUX:-} ]] || [[ -n ${SSH_TTY:-} ]]; then
  data=$(base64 | tr -d '\n')
  printf '\033]52;c;%s\a' "$data"
  exit 0
fi

printf 'No clipboard backend available\n' >&2
exit 1
