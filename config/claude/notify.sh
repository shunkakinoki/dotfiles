#!/usr/bin/env bash

# Claude Code Local Notification Script
# Sends macOS notifications via osascript
# Skips if Pushover is configured (to avoid duplicate notifications)

# Source credentials to check if Pushover is configured
if [ -z "$PUSHOVER_API_TOKEN" ] || [ -z "$PUSHOVER_USER_KEY" ]; then
  if [ -f "$HOME/dotfiles/.env" ]; then
    set -a
    source "$HOME/dotfiles/.env" 2>/dev/null
    set +a
  fi
fi

# Exit if Pushover is configured (pushover.sh will handle notifications)
if [ -n "$PUSHOVER_API_TOKEN" ] && [ -n "$PUSHOVER_USER_KEY" ]; then
  exit 0
fi

# Read JSON input from stdin
input=$(cat)

# Function to send local macOS notification
notify() {
  local message="$1"
  local sound="${2:-Sonar}"

  [ -z "$message" ] && return

  osascript -e "display notification \"${message}\" with title \"Claude Code\" sound name \"${sound}\"" 2>/dev/null
}

# Handle Notification hook
if echo "$input" | jq -e '.message' >/dev/null 2>&1; then
  MESSAGE=$(echo "$input" | jq -r '.message')

  case "$MESSAGE" in
  'Claude is waiting for your input')
    notify "Waiting for your input"
    ;;
  'Claude Code login successful')
    exit 0
    ;;
  'Claude needs your permission to use '*)
    TOOL="${MESSAGE#Claude needs your permission to use }"
    notify "${TOOL} permission required" "Basso"
    ;;
  *)
    notify "${MESSAGE}"
    ;;
  esac
  exit 0
fi

# Handle SessionEnd hook
if echo "$input" | jq -e '.reason' >/dev/null 2>&1; then
  REASON=$(echo "$input" | jq -r '.reason')
  notify "Session ended: ${REASON}"
  exit 0
fi

# Handle PreCompact hook
if echo "$input" | jq -e '.trigger' >/dev/null 2>&1; then
  TRIGGER=$(echo "$input" | jq -r '.trigger')
  if [ "$TRIGGER" = "auto" ]; then
    notify "Auto-compacting context"
  else
    notify "Manual compact triggered"
  fi
  exit 0
fi

# Handle SubagentStop hook
if echo "$input" | jq -e '.stop_hook_active' >/dev/null 2>&1; then
  notify "Subagent task completed"
  exit 0
fi

# Handle Stop hook
if echo "$input" | jq -e '.session_id' >/dev/null 2>&1; then
  CWD=$(echo "$input" | jq -r '.cwd // "unknown"' | sed "s|$HOME|~|")
  SESSION_ID=$(echo "$input" | jq -r '.session_id[0:8]')
  notify "Work completed in ${CWD} (${SESSION_ID})"
  exit 0
fi

# Handle PreToolUse hook (risky command warning)
if echo "$input" | jq -e '.tool.name' >/dev/null 2>&1; then
  TOOL_NAME=$(echo "$input" | jq -r '.tool.name')
  if [ "$TOOL_NAME" = "Bash" ]; then
    TOOL_INPUT=$(echo "$input" | jq -r '.tool.input // ""')
    if echo "$TOOL_INPUT" | grep -qiE 'rm -rf|drop database|truncate|DELETE FROM|format'; then
      RISKY_MSG=$(echo "$TOOL_INPUT" | head -c 100)
      notify "Risky: ${RISKY_MSG}" "Basso"
    fi
  fi
  exit 0
fi

exit 0
