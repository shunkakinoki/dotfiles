#!/usr/bin/env bash

set -euo pipefail

is_ssh() {
  [[ -n ${SSH_TTY:-} || -n ${SSH_CONNECTION:-} || -n ${SSH_CLIENT:-} ]]
}

# Always print OSC 52 on stdout so tests and interactive shells see it.
# When stdout is not a tty (tmux/zellij copy-pipe), also write the pane tty
# so the sequence actually reaches the terminal.
osc52_emit() {
  local data seq
  data=$(base64 | tr -d '\n')
  seq=$(printf '\033]52;c;%s\a' "$data")
  printf '%s' "$seq"
  if [[ ! -t 1 && (-n ${TMUX:-} || -n ${ZELLIJ:-}) ]]; then
    {
      if [[ -n ${SSH_TTY:-} && -w ${SSH_TTY} ]]; then
        printf '%s' "$seq" >"$SSH_TTY"
      elif [[ -e /dev/tty && -w /dev/tty ]]; then
        printf '%s' "$seq" >/dev/tty
      fi
    } 2>/dev/null || true
  fi
}

cache_path() {
  printf '%s/clipboard/data' "${XDG_CACHE_HOME:-$HOME/.cache}"
}

if is_ssh; then
  dir=$(dirname "$(cache_path)")
  mkdir -p "$dir"
  chmod 700 "$dir"
  umask 077
  # Preserve exact stdin (including trailing newlines) for paste fallback.
  tee "$(cache_path)" | osc52_emit
  exit 0
fi

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

# OSC 52 fallback: works over multiplexers if the terminal supports it
# (ghostty, iTerm2, kitty, alacritty, tmux, etc.)
if [[ -t 1 ]] || [[ -n ${TMUX:-} ]] || [[ -n ${ZELLIJ:-} ]]; then
  osc52_emit
  exit 0
fi

printf 'No clipboard backend available\n' >&2
exit 1
