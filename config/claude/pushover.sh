#!/usr/bin/env bash

# Claude Code Pushover Notification Script
# Sends notifications to your smartwatch/phone when Claude needs attention
# Supports: Notification, Stop, SessionEnd, PreCompact, SubagentStop hooks

# Exit early if Pushover is not configured
if [ -z "$PUSHOVER_API_TOKEN" ] || [ -z "$PUSHOVER_USER_KEY" ]; then
  exit 0
fi

# Read JSON input from stdin
input=$(cat)

# Function to send Pushover notification
send_notification() {
  local message="$1"
  local priority="${2:-0}" # -1=low, 0=normal, 1=high, 2=emergency

  # Skip if no message
  [ -z "$message" ] && return

  curl -s \
    --form-string "token=${PUSHOVER_API_TOKEN}" \
    --form-string "user=${PUSHOVER_USER_KEY}" \
    --form-string "message=${message}" \
    --form-string "priority=${priority}" \
    --form-string "device=iphone15" \
    --form-string "title=Claude Code" \
    https://api.pushover.net/1/messages.json >/dev/null 2>&1
}

# Handle Notification hook
if echo "$input" | jq -e '.message' >/dev/null 2>&1; then
  MESSAGE=$(echo "$input" | jq -r '.message')

  case "$MESSAGE" in
  'Claude is waiting for your input')
    send_notification "⏸️ Waiting for your input" 1
    ;;
  'Claude Code login successful')
    # No need to notify on login - user is already active
    exit 0
    ;;
  'Claude needs your permission to use '*)
    TOOL="${MESSAGE#Claude needs your permission to use }"
    send_notification "🔐 ${TOOL} permission required" 1
    ;;
  *)
    send_notification "ℹ️ ${MESSAGE}" 0
    ;;
  esac
  exit 0
fi

# Handle SessionEnd hook
if echo "$input" | jq -e '.reason' >/dev/null 2>&1; then
  REASON=$(echo "$input" | jq -r '.reason')
  send_notification "👋 Session ended: ${REASON}" -1
  exit 0
fi

# Handle SessionStart hook
# Uncomment if you want session start notifications
# if echo "$input" | jq -e '.source' >/dev/null 2>&1; then
#     SOURCE=$(echo "$input" | jq -r '.source')
#     case "$SOURCE" in
#         'startup')
#             send_notification "🚀 Claude Code session started" -1
#             ;;
#         'resume')
#             send_notification "▶️ Claude Code session resumed" -1
#             ;;
#         'clear')
#             send_notification "🔄 Claude Code session cleared" -1
#             ;;
#     esac
#     exit 0
# fi

# Handle PreCompact hook
if echo "$input" | jq -e '.trigger' >/dev/null 2>&1; then
  TRIGGER=$(echo "$input" | jq -r '.trigger')
  if [ "$TRIGGER" = "auto" ]; then
    send_notification "🗜️ Auto-compacting context" -1
  else
    send_notification "🗜️ Manual compact triggered" -1
  fi
  exit 0
fi

# Handle SubagentStop hook
if echo "$input" | jq -e '.stop_hook_active' >/dev/null 2>&1; then
  send_notification "🤖 Subagent task completed" -1
  exit 0
fi

# Handle Stop hook (main session completion)
if echo "$input" | jq -e '.session_id' >/dev/null 2>&1; then
  SESSION_ID=$(echo "$input" | jq -r '.session_id[0:8]')
  CWD=$(echo "$input" | jq -r '.cwd // "unknown"' | sed "s|$HOME|~|")
  send_notification "✅ Work completed in ${CWD}" -1
  exit 0
fi

# Handle PreToolUse hook (disabled by default - too noisy)
# if echo "$input" | jq -e '.tool.name' >/dev/null 2>&1; then
#     TOOL_NAME=$(echo "$input" | jq -r '.tool.name')
#     send_notification "🔧 Using tool: ${TOOL_NAME}" -1
#     exit 0
# fi

# Handle PostToolUse hook (disabled by default - too noisy)
# if echo "$input" | jq -e '.response' >/dev/null 2>&1; then
#     TOOL_NAME=$(echo "$input" | jq -r '.tool.name // "unknown"')
#     send_notification "✓ Tool completed: ${TOOL_NAME}" -1
#     exit 0
# fi

exit 0
