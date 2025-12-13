#!/usr/bin/env bash

# Claude Code Pushover Notification Script
# Sends notifications to your smartwatch/phone when Claude needs attention
# Supports: Notification, Stop, SessionEnd, PreCompact, SubagentStop hooks

# Source credentials from dotfiles/.env if environment variables aren't set
# This is needed because Claude Code hooks run in a subprocess that may not
# inherit shell environment variables
if [ -z "$PUSHOVER_API_TOKEN" ] || [ -z "$PUSHOVER_USER_KEY" ]; then
  if [ -f "$HOME/dotfiles/.env" ]; then
    set -a
    # shellcheck source=/dev/null
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
  TRANSCRIPT_PATH=$(echo "$input" | jq -r '.transcript_path // empty')

  # Extract stats from transcript if available
  if [ -n "$TRANSCRIPT_PATH" ] && [ -f "$TRANSCRIPT_PATH" ]; then
    TOOL_COUNT=$(jq -s '[.[] | select(.type=="tool_use")] | length' "$TRANSCRIPT_PATH" 2>/dev/null || echo "0")
    FILE_COUNT=$(jq -rs '[.[] | select(.type=="tool_use" and (.tool_use.name=="Write" or .tool_use.name=="Edit")) | .tool_use.input.file_path // empty] | unique | length' "$TRANSCRIPT_PATH" 2>/dev/null || echo "0")
    CWD=$(jq -rs '[.[] | select(.cwd) | .cwd] | first // empty' "$TRANSCRIPT_PATH" 2>/dev/null | sed "s|$HOME|~|")
    TASK=$(jq -rs '[.[] | select(.type=="user") | .message.content[]? | select(.type=="text") | .text] | map(select(startswith("<") | not)) | first // empty' "$TRANSCRIPT_PATH" 2>/dev/null | head -c 50)
    STATS="${TOOL_COUNT} tools, ${FILE_COUNT} files"
  else
    CWD=$(echo "$input" | jq -r '.cwd // empty' | sed "s|$HOME|~|")
    STATS=""
    TASK=""
  fi

  case "$MESSAGE" in
  'Claude is waiting for your input')
    if [ -n "$TASK" ]; then
      send_notification "⏸️ Waiting for input: ${STATS}
📂 ${CWD}
💬 ${TASK}" 1
    else
      send_notification "⏸️ Waiting for input
📂 ${CWD}" 1
    fi
    ;;
  'Claude Code login successful')
    # No need to notify on login - user is already active
    exit 0
    ;;
  *'permission'* | *'Permission'*)
    if [ -n "$TASK" ]; then
      send_notification "🔐 Permission required: ${STATS}
📂 ${CWD}
💬 ${TASK}" 1
    else
      send_notification "🔐 Permission required
📂 ${CWD}" 1
    fi
    ;;
  *'plan'* | *'Plan'* | *'approval'* | *'Approval'*)
    if [ -n "$TASK" ]; then
      send_notification "📋 Plan ready: ${STATS}
📂 ${CWD}
💬 ${TASK}" 1
    else
      send_notification "📋 Plan ready for review
📂 ${CWD}" 1
    fi
    ;;
  *'waiting'* | *'Waiting'*)
    if [ -n "$TASK" ]; then
      send_notification "⏸️ Waiting: ${STATS}
📂 ${CWD}
💬 ${TASK}" 1
    else
      send_notification "⏸️ Waiting for input
📂 ${CWD}" 1
    fi
    ;;
  *)
    send_notification "ℹ️ ${MESSAGE}" -1
    ;;
  esac
  exit 0
fi

# Handle SessionEnd hook (priority 0 = normal)
# Skip "other" reason - it's a generic/unknown reason that's noisy
if echo "$input" | jq -e '.reason' >/dev/null 2>&1; then
  REASON=$(echo "$input" | jq -r '.reason')
  if [ "$REASON" = "other" ]; then
    exit 0
  fi
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
    # Extract stats from transcript
    TOOL_COUNT=$(jq -s '[.[] | select(.type=="tool_use")] | length' "$TRANSCRIPT_PATH" 2>/dev/null || echo "0")
    FILE_COUNT=$(jq -rs '[.[] | select(.type=="tool_use" and (.tool_use.name=="Write" or .tool_use.name=="Edit")) | .tool_use.input.file_path // empty] | unique | length' "$TRANSCRIPT_PATH" 2>/dev/null || echo "0")

    # Extract working directory from first entry with cwd
    CWD=$(jq -rs '[.[] | select(.cwd) | .cwd] | first // empty' "$TRANSCRIPT_PATH" 2>/dev/null | sed "s|$HOME|~|")
    [ -z "$CWD" ] && CWD="unknown"

    # Extract first actual user prompt (skip <ide_*> and <system-*> tags)
    TASK=$(jq -rs '
      [.[] | select(.type=="user") | .message.content[]? | select(.type=="text") | .text]
      | map(select(startswith("<") | not))
      | first // empty
    ' "$TRANSCRIPT_PATH" 2>/dev/null | head -c 50)

    # Check if this is plan approval waiting vs work completed
    # Plan approval = ExitPlanMode was the last tool AND no files were modified
    # Work completed = Files were changed OR last tool was not ExitPlanMode
    LAST_TOOL=$(jq -rs '
      [.[] | select(.type=="assistant") | .message.content[]? | select(.type=="tool_use") | .name]
      | last // ""
    ' "$TRANSCRIPT_PATH" 2>/dev/null)

    PERMISSION_MODE=$(echo "$input" | jq -r '.permission_mode // "default"')

    # Only show "Plan ready for approval" if:
    # 1. permission_mode is "plan" AND
    # 2. ExitPlanMode was the last tool AND
    # 3. No files were modified (FILE_COUNT == 0)
    if [ "$PERMISSION_MODE" = "plan" ] && [ "$LAST_TOOL" = "ExitPlanMode" ] && [ "$FILE_COUNT" = "0" ]; then
      send_notification "📋 Plan ready for approval
📂 ${CWD}
💬 ${TASK}" 1
      exit 0
    fi

    if [ -n "$TASK" ]; then
      send_notification "✅ Work completed: ${TOOL_COUNT} tools, ${FILE_COUNT} files
📂 ${CWD}
💬 ${TASK}" 0
    else
      send_notification "✅ Work completed: ${TOOL_COUNT} tools, ${FILE_COUNT} files
📂 ${CWD}" 0
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
