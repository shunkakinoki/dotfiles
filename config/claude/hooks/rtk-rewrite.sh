#!/usr/bin/env bash
# rtk-hook-version: 3
# RTK auto-rewrite hook for Claude/Codex/Copilot PreToolUse shell commands.
# Transparently rewrites raw commands to their RTK equivalents.
# Uses `rtk rewrite` as single source of truth — no duplicate mapping logic here.
#
# To add support for new commands, update src/discover/registry.rs (PATTERNS + RULES).
#
# Exit code protocol for `rtk rewrite`:
#   0 + stdout  Rewrite found, no deny/ask rule matched → auto-allow
#   1           No RTK equivalent → pass through unchanged
#   2           Deny rule matched → pass through (Claude Code native deny handles it)
#   3 + stdout  Ask rule matched → rewrite but let Claude Code prompt the user

# --- Audit logging (opt-in via RTK_HOOK_AUDIT=1) ---
_rtk_audit_log() {
  if [ "${RTK_HOOK_AUDIT:-0}" != "1" ]; then return; fi
  local action="$1" original="$2" rewritten="${3:--}"
  local dir="${RTK_AUDIT_DIR:-${HOME}/.local/share/rtk}"
  mkdir -p "$dir"
  printf '%s | %s | %s | %s\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$action" "$original" "$rewritten" \
    >> "${dir}/hook-audit.log"
}

# Guards: skip silently if dependencies missing
if ! command -v rtk &>/dev/null || ! command -v jq &>/dev/null; then
  _rtk_audit_log "skip:no_deps" "-"
  exit 0
fi

set -euo pipefail

INPUT=$(cat)
CMD=$(echo "$INPUT" | jq -r '
  .tool.input.command
  // .tool_input.command
  // (.toolArgs | if type == "object" then .command else empty end)
  // (.toolArgs | if type == "string" then (fromjson? | .command) else empty end)
  // .toolInput.command
  // .command
  // empty
')

if [ -z "$CMD" ]; then
  _rtk_audit_log "skip:empty" "-"
  exit 0
fi

# Skip heredocs (rtk rewrite also skips them, but bail early)
case "$CMD" in
  *'<<'*) _rtk_audit_log "skip:heredoc" "$CMD"; exit 0 ;;
esac

# Rewrite via rtk — single source of truth for all command mappings and permission checks.
# Use "|| EXIT_CODE=$?" to capture non-zero exit codes without triggering set -e.
EXIT_CODE=0
REWRITTEN=$(rtk rewrite "$CMD" 2>/dev/null) || EXIT_CODE=$?

case $EXIT_CODE in
  0)
    # Rewrite found, no permission rules matched — safe to auto-allow.
    if [ "$CMD" = "$REWRITTEN" ]; then
      _rtk_audit_log "skip:already_rtk" "$CMD"
      exit 0
    fi
    ;;
  1)
    # No RTK equivalent — pass through unchanged.
    _rtk_audit_log "skip:no_match" "$CMD"
    exit 0
    ;;
  2)
    # Deny rule matched — let Claude Code's native deny rule handle it.
    _rtk_audit_log "skip:deny_rule" "$CMD"
    exit 0
    ;;
  3)
    # Ask rule matched — rewrite the command but do NOT auto-allow so that
    # Claude Code prompts the user for confirmation.
    ;;
  *)
    exit 0
    ;;
esac

_rtk_audit_log "rewrite" "$CMD" "$REWRITTEN"

# Build the updated tool input with all original fields preserved, only command changed.
ORIGINAL_INPUT=$(echo "$INPUT" | jq -c '
  (
    .tool_input
    // .tool.input
    // .toolArgs
    // .toolInput
    // {}
  ) | if type == "string" then (fromjson? // {}) else . end
')
UPDATED_INPUT=$(echo "$ORIGINAL_INPUT" | jq --arg cmd "$REWRITTEN" '.command = $cmd')
IS_COPILOT_INPUT=$(echo "$INPUT" | jq -r 'has("toolName") and has("toolArgs")')

if [ "$IS_COPILOT_INPUT" = "true" ]; then
  if [ "$EXIT_CODE" -eq 3 ]; then
    jq -n \
      --argjson modified "$UPDATED_INPUT" \
      '{
        "permissionDecision": "ask",
        "modifiedArgs": $modified
      }'
  else
    jq -n \
      --argjson modified "$UPDATED_INPUT" \
      '{
        "permissionDecision": "allow",
        "permissionDecisionReason": "RTK auto-rewrite",
        "modifiedArgs": $modified
      }'
  fi
elif [ "$EXIT_CODE" -eq 3 ]; then
  # Ask: rewrite the command, omit permissionDecision so Claude Code prompts.
  jq -n \
    --argjson updated "$UPDATED_INPUT" \
    '{
      "hookSpecificOutput": {
        "hookEventName": "PreToolUse",
        "updatedInput": $updated
      }
    }'
else
  # Allow: output the rewrite instruction in Claude Code hook format.
  jq -n \
    --argjson updated "$UPDATED_INPUT" \
    '{
      "hookSpecificOutput": {
        "hookEventName": "PreToolUse",
        "permissionDecision": "allow",
        "permissionDecisionReason": "RTK auto-rewrite",
        "updatedInput": $updated
      }
    }'
fi
