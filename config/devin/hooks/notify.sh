#!/usr/bin/env bash
# Devin local notification hook.
set -euo pipefail

input=$(cat)
command -v jq >/dev/null 2>&1 || exit 0

notifier="$(command -v notify-local 2>/dev/null || true)"
[[ -z $notifier && -x "$HOME/.local/scripts/notify-local" ]] && notifier="$HOME/.local/scripts/notify-local"
[[ -z $notifier ]] && exit 0

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

[[ -n $message ]] && "$notifier" "Devin" "$message" "Sonar"
exit 0
