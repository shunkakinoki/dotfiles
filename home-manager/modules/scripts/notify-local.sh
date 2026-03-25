#!/usr/bin/env bash

set -euo pipefail

title="${1:-Notification}"
message="${2:-}"
sound="${3:-}"

if [[ -z "$message" ]]; then
  exit 0
fi

title="${title//$'\n'/ }"
message="${message//$'\n'/ }"
sound="${sound//$'\n'/ }"

escape_applescript() {
  local value="$1"

  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"

  printf '%s' "$value"
}

if command -v osascript >/dev/null 2>&1; then
  escaped_title="$(escape_applescript "$title")"
  escaped_message="$(escape_applescript "$message")"

  if [[ -n "$sound" ]]; then
    escaped_sound="$(escape_applescript "$sound")"
    osascript -e "display notification \"$escaped_message\" with title \"$escaped_title\" sound name \"$escaped_sound\"" >/dev/null 2>&1 || true
  else
    osascript -e "display notification \"$escaped_message\" with title \"$escaped_title\"" >/dev/null 2>&1 || true
  fi

  exit 0
fi

if command -v notify-send >/dev/null 2>&1; then
  notify-send "$title" "$message" >/dev/null 2>&1 || true
  exit 0
fi

if command -v terminal-notifier >/dev/null 2>&1; then
  terminal-notifier -title "$title" -message "$message" >/dev/null 2>&1 || true
  exit 0
fi

exit 0
