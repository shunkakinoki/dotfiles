#!/usr/bin/env bash
# Devin Pushover notification hook.
set -euo pipefail

if [[ -z ${PUSHOVER_API_TOKEN:-} || -z ${PUSHOVER_USER_KEY:-} ]] && [[ -f "$HOME/dotfiles/.env" ]]; then
  set -a
  # shellcheck source=/dev/null
  source "$HOME/dotfiles/.env" 2>/dev/null || true
  set +a
fi

[[ -n ${PUSHOVER_API_TOKEN:-} && -n ${PUSHOVER_USER_KEY:-} ]] || exit 0
input=$(cat)
command -v jq >/dev/null 2>&1 || exit 0

event=$(jq -r '.hook_event_name // empty' <<<"$input")
message=''
case "$event" in
SessionStart) message='Session started' ;;
Stop) message='Work completed' ;;
PermissionRequest) message="Approval required: $(jq -r '.tool_name // "unknown"' <<<"$input")" ;;
PreToolUse)
  command=$(jq -r '.tool_input.command // empty' <<<"$input")
  if [[ $command =~ (rm[[:space:]]+-rf|drop[[:space:]]+database|truncate|DELETE[[:space:]]+FROM|format) ]]; then
    message="Risky: ${command:0:100}"
  fi
  ;;
PostCompaction) message='Context compacted' ;;
esac

[[ -n $message ]] || exit 0
host=$(hostname -s 2>/dev/null || printf '%s' unknown)
curl -s --max-time 5 --connect-timeout 3 \
  --form-string "token=${PUSHOVER_API_TOKEN}" \
  --form-string "user=${PUSHOVER_USER_KEY}" \
  --form-string "message=[${host}] ${message}" \
  --form-string 'title=Devin' \
  https://api.pushover.net/1/messages.json >/dev/null 2>&1 || true
exit 0
