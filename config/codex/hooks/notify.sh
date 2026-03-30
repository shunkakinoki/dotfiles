#!/usr/bin/env bash

# Codex local notification hook
# Sends native OS notifications via the shared notify-local script.
# Skips local popups when Pushover is configured (pushover.sh handles those).

# Source credentials to check if Pushover is configured
if [[ -z ${PUSHOVER_API_TOKEN:-} ]] || [[ -z ${PUSHOVER_USER_KEY:-} ]]; then
  if [[ -f "$HOME/dotfiles/.env" ]]; then
    set -a
    # shellcheck source=/dev/null
    source "$HOME/dotfiles/.env" 2>/dev/null
    set +a
  fi
fi

# Exit if Pushover is configured (pushover.sh will handle notifications)
if [[ -n ${PUSHOVER_API_TOKEN:-} ]] && [[ -n ${PUSHOVER_USER_KEY:-} ]]; then
  exit 0
fi

input=$(cat)

notify() {
  local message="$1"
  local sound="${2:-Sonar}"
  local notifier

  [[ -z $message ]] && return

  notifier="$(command -v notify-local 2>/dev/null || true)"
  if [[ -z $notifier ]] && [[ -x "$HOME/.local/scripts/notify-local" ]]; then
    notifier="$HOME/.local/scripts/notify-local"
  fi

  [[ -n $notifier ]] && "$notifier" "Codex" "$message" "$sound"
}

event=$(echo "$input" | jq -r '.hook_event_name // empty' 2>/dev/null)

case "$event" in
SessionStart)
  source=$(echo "$input" | jq -r '.source // "startup"')
  case "$source" in
  startup) notify "Session started" ;;
  resume) notify "Session resumed" ;;
  esac
  ;;
Stop)
  last_msg=$(echo "$input" | jq -r '.last_assistant_message // empty' | head -c 80)
  if [[ -n $last_msg ]]; then
    notify "Work completed: ${last_msg}"
  else
    notify "Work completed"
  fi
  ;;
PreToolUse)
  command=$(echo "$input" | jq -r '.tool_input.command // empty')
  if echo "$command" | grep -qiE 'rm -rf|drop database|truncate|DELETE FROM|format'; then
    risky_msg=$(echo "$command" | head -c 100)
    notify "Risky: ${risky_msg}" "Basso"
  fi
  ;;
esac

exit 0
