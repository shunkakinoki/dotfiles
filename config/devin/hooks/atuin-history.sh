#!/usr/bin/env bash
# Record Devin exec tool commands through Atuin's start/end API.
set -euo pipefail

hook_input=$(cat)
command -v atuin >/dev/null 2>&1 || exit 0
command -v jq >/dev/null 2>&1 || exit 0

tool_name=$(jq -r '.tool_name // .tool.name // empty' <<<"$hook_input")
[ "$tool_name" = "exec" ] || exit 0

bash_command=$(jq -r '.tool_input.command // .tool.input.command // empty' <<<"$hook_input")
[ -n "$bash_command" ] || exit 0

exit_code=$(jq -r '.tool_result.exit_code // .tool_response.exit_code // .response.exit_code // 0' <<<"$hook_input")
case "$exit_code" in ''|-*|*[!0-9]*) exit_code=0 ;; esac
duration=$(jq -r '.tool_result.duration_ms // .tool_response.duration_ms // .response.duration_ms // 0' <<<"$hook_input")
case "$duration" in ''|*[!0-9]*) duration=0 ;; esac

cwd=$(jq -r '.cwd // empty' <<<"$hook_input")
[ -n "$cwd" ] && [ -d "$cwd" ] || cwd="$HOME"

(
  cd "$cwd" || exit 0
  export ATUIN_HISTORY_AUTHOR="devin"
  history_id=$(atuin history start -- "$bash_command") || exit 0
  atuin history end --exit "$exit_code" --duration "$duration" "$history_id"
) >/dev/null 2>&1
exit 0
