#!/usr/bin/env bash

# Claude Code Pushover Notification Script
# Sends notifications to your smartwatch/phone when Claude needs attention
# Supports: Notification, Stop, SessionEnd, PreCompact, SubagentStop hooks

# Source credentials from dotfiles/.env if environment variables aren't set
# This is needed because Claude Code hooks run in a subprocess that may not
# inherit shell environment variables
if [ -z "$PUSHOVER_API_TOKEN" ] || [ -z "$PUSHOVER_USER_KEY" ]; then
  if [ -f "$HOME/dotfiles/.env" ]; then
    # shellcheck source=/dev/null
    set -a
    source "$HOME/dotfiles/.env" 2>/dev/null
    set +a
  fi
fi

# Exit if still not configured
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
    send_notification "ℹ️ ${MESSAGE}" -1
    ;;
  esac
  exit 0
fi

# Handle SessionEnd hook (priority 0 = normal)
if echo "$input" | jq -e '.reason' >/dev/null 2>&1; then
  REASON=$(echo "$input" | jq -r '.reason')
  send_notification "👋 Session ended: ${REASON}" 0
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

# Handle SubagentStop hook (priority 0 = normal)
if echo "$input" | jq -e '.stop_hook_active' >/dev/null 2>&1; then
  send_notification "🤖 Subagent task completed" -1
  exit 0
fi

# Handle Stop hook (priority 0 = normal - Claude finished)
if echo "$input" | jq -e '.hook_event_name == "Stop"' >/dev/null 2>&1; then
  TRANSCRIPT_PATH=$(echo "$input" | jq -r '.transcript_path')

  if [ -f "$TRANSCRIPT_PATH" ]; then
    # Extract first user message as title (truncated to 50 chars)
    TITLE=$(jq -rs '[.[] | select(.type=="user")] | first | .message.content[0].text // empty' "$TRANSCRIPT_PATH" 2>/dev/null | head -c 50)
    [ -z "$TITLE" ] && TITLE="Work completed"

    # Get unique files modified (Write and Edit tools)
    FILES_MODIFIED=$(jq -rs '
      [.[] | select(.type=="tool_use" and (.tool_use.name=="Write" or .tool_use.name=="Edit"))
       | .tool_use.input.file_path // empty]
      | unique
      | map(split("/") | last)
      | join(", ")
    ' "$TRANSCRIPT_PATH" 2>/dev/null)

    if [ -n "$FILES_MODIFIED" ]; then
      send_notification "✅ ${TITLE}
📝 ${FILES_MODIFIED}" 0
    else
      send_notification "✅ ${TITLE}" 0
    fi
  else
    send_notification "✅ Work completed" 0
  fi
  exit 0
fi

# Handle PreToolUse hook (risky command warning only)
if echo "$input" | jq -e '.tool.name' >/dev/null 2>&1; then
  TOOL_NAME=$(echo "$input" | jq -r '.tool.name')
  if [ "$TOOL_NAME" = "Bash" ]; then
    TOOL_INPUT=$(echo "$input" | jq -r '.tool.input // ""')
    if echo "$TOOL_INPUT" | grep -qiE 'rm -rf|drop database|truncate|DELETE FROM|format'; then
      RISKY_MSG=$(echo "$TOOL_INPUT" | head -c 100)
      send_notification "⚠️ Risky: ${RISKY_MSG}" 1
    fi
  fi
  exit 0
fi

# Handle PostToolUse hook (disabled by default - too noisy)
# if echo "$input" | jq -e '.response' >/dev/null 2>&1; then
#     TOOL_NAME=$(echo "$input" | jq -r '.tool.name // "unknown"')
#     send_notification "✓ Tool completed: ${TOOL_NAME}" -1
#     exit 0
# fi

exit 0
