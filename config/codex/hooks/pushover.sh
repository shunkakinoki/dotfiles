#!/usr/bin/env bash

# Codex Pushover notification hook
# Sends notifications to phone/watch via the shared pushover-notify script.

input=$(cat)

# Resolve the shared pushover sender
pushover="$(command -v pushover-notify 2>/dev/null || true)"
if [[ -z $pushover ]] && [[ -x "$HOME/.local/scripts/pushover-notify" ]]; then
  pushover="$HOME/.local/scripts/pushover-notify"
fi
[[ -z $pushover ]] && exit 0

# Skip notifications only for pure timer-driven Paperclip heartbeats.
# PAPERCLIP_RUN_ID is set for every adapter run, but TASK_ID / WAKE_REASON
# are only set when the wake came from an explicit trigger. A bare heartbeat
# has RUN_ID with no TASK_ID and no WAKE_REASON -- silence that case only.
if [[ -n ${PAPERCLIP_RUN_ID:-} ]] && [[ -z ${PAPERCLIP_TASK_ID:-} ]] && [[ -z ${PAPERCLIP_WAKE_REASON:-} ]]; then
  exit 0
fi

HOSTNAME=$(scutil --get ComputerName 2>/dev/null || hostname -s 2>/dev/null || echo "unknown")
CWD=$(echo "$input" | jq -r '.cwd // empty' | sed "s|$HOME|~|")

event=$(echo "$input" | jq -r '.hook_event_name // empty' 2>/dev/null)

case "$event" in
SessionStart)
  source=$(echo "$input" | jq -r '.source // "startup"')
  case "$source" in
  startup) "$pushover" "Codex" "[$HOSTNAME] Session started in ${CWD}" -1 ;;
  resume) "$pushover" "Codex" "[$HOSTNAME] Session resumed in ${CWD}" -1 ;;
  esac
  ;;
Stop)
  last_msg=$(echo "$input" | jq -r '.last_assistant_message // empty' | head -c 80)
  if [[ -n $last_msg ]]; then
    "$pushover" "Codex" "[$HOSTNAME] Work completed in ${CWD}
${last_msg}" 0
  else
    "$pushover" "Codex" "[$HOSTNAME] Work completed in ${CWD}" 0
  fi
  ;;
PreToolUse)
  command=$(echo "$input" | jq -r '.tool_input.command // empty')
  if echo "$command" | grep -qiE 'rm -rf|drop database|truncate|DELETE FROM|format'; then
    risky_msg=$(echo "$command" | head -c 100)
    "$pushover" "Codex" "[$HOSTNAME] Risky: ${risky_msg}" 1
  fi
  ;;
UserPromptSubmit)
  # Silent - no notification for user prompts
  ;;
esac

exit 0
