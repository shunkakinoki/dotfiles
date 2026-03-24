#!/usr/bin/env bash

# Save start timestamp before Bash tool execution for duration tracking.
# Paired with atuin-history.sh (PostToolUse) which computes elapsed time.

hook_input=$(cat)

[ -n "$hook_input" ] || exit 0

command -v jq >/dev/null 2>&1 || exit 0

tool_name=$(jq -r '.tool_name // .tool.name // empty' <<<"$hook_input")

[ "$tool_name" = "Bash" ] || exit 0

session_id=$(jq -r '.session_id // empty' <<<"$hook_input")

[ -n "$session_id" ] || exit 0

epoch_ms=$(gdate +%s%3N 2>/dev/null || date +%s%3N 2>/dev/null) || exit 0

timer_dir="${TMPDIR:-/tmp}/claude-atuin-timer"
mkdir -p "$timer_dir"
printf '%s' "$epoch_ms" >"$timer_dir/$session_id"

exit 0
