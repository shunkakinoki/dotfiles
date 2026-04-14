#!/usr/bin/env bash

# Generic Pushover notification sender
# Usage: pushover-notify "title" "message" [priority]
# Priority: -1=low, 0=normal (default), 1=high, 2=emergency

set -euo pipefail

title="${1:-Notification}"
message="${2:-}"
priority="${3:-0}"

[[ -z $message ]] && exit 0

# Source credentials only when the vars are unset. Explicitly blank values
# should disable notifications instead of falling back to ~/.env.
if [[ -z ${PUSHOVER_API_TOKEN+x} ]] || [[ -z ${PUSHOVER_USER_KEY+x} ]]; then
  if [[ -f "$HOME/dotfiles/.env" ]]; then
    set -a
    # shellcheck source=/dev/null
    source "$HOME/dotfiles/.env" 2>/dev/null
    set +a
  fi
fi

# Exit if still not configured
if [[ -z ${PUSHOVER_API_TOKEN:-} ]] || [[ -z ${PUSHOVER_USER_KEY:-} ]]; then
  exit 0
fi

curl -s \
  --max-time 5 \
  --connect-timeout 3 \
  --form-string "token=${PUSHOVER_API_TOKEN}" \
  --form-string "user=${PUSHOVER_USER_KEY}" \
  --form-string "message=${message}" \
  --form-string "priority=${priority}" \
  --form-string "title=${title}" \
  https://api.pushover.net/1/messages.json >/dev/null 2>&1 || exit 0
