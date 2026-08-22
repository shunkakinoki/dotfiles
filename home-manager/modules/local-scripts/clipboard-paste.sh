#!/usr/bin/env bash

set -euo pipefail

is_ssh() {
  [[ -n ${SSH_TTY:-} || -n ${SSH_CONNECTION:-} || -n ${SSH_CLIENT:-} ]]
}

cache_path() {
  printf '%s/clipboard/data' "${XDG_CACHE_HOME:-$HOME/.cache}"
}

# Query the local terminal clipboard via OSC 52. Only talks to SSH_TTY so
# tests/CI never raw-mode the runner's /dev/tty. Ghostty allows this when
# clipboard-read = allow.
osc52_paste() {
  local tty
  if [[ -n ${SSH_TTY:-} && -c ${SSH_TTY} && -r ${SSH_TTY} && -w ${SSH_TTY} ]]; then
    tty=$SSH_TTY
  else
    return 1
  fi

  local saved
  saved=$(stty -g <"$tty" 2>/dev/null) || return 1
  # shellcheck disable=SC2064
  trap 'stty "$saved" <"$tty" 2>/dev/null || true' EXIT
  stty raw -echo min 0 time 10 <"$tty" || return 1
  printf '\033]52;c;?\a' >"$tty"

  local buf="" c
  while IFS= read -r -n 1 c <"$tty"; do
    buf+="$c"
    if [[ $buf == *$'\a' || $buf == *$'\033\\' ]]; then
      break
    fi
    if ((${#buf} > 2000000)); then
      break
    fi
  done

  stty "$saved" <"$tty" 2>/dev/null || true
  trap - EXIT

  local b64=${buf#*$'\033]52;'}
  [[ $b64 != "$buf" ]] || return 1
  b64=${b64#*;}
  b64=${b64%$'\a'}
  b64=${b64%$'\033\\'}
  [[ -n $b64 ]] || return 1
  if printf '%s' "$b64" | base64 -d 2>/dev/null; then
    return 0
  fi
  printf '%s' "$b64" | base64 -D 2>/dev/null || return 1
}

if is_ssh; then
  if osc52_paste; then
    exit 0
  fi
  cache=$(cache_path)
  if [[ -f $cache ]]; then
    cat "$cache"
    exit 0
  fi
  printf 'No clipboard backend available (paste not supported over SSH)\n' >&2
  exit 1
fi

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

printf 'No clipboard backend available (paste not supported over SSH)\n' >&2
exit 1
