#!/usr/bin/env bash

# Record completed Codex Bash tool commands in Atuin history.
# Codex's Bash tool runs non-interactively, so Atuin's shell hooks never see it.

hook_input=$(cat)

[ -n "$hook_input" ] || exit 0

if ! command -v atuin >/dev/null 2>&1 || ! command -v jq >/dev/null 2>&1; then
  exit 0
fi

jq_read() {
  jq -r "$1" <<<"$hook_input"
}

tool_name=$(jq_read '.tool_name // empty')
[ "$tool_name" = "Bash" ] || exit 0

bash_command=$(jq_read '.tool_input.command // empty')
[ -n "$bash_command" ] || exit 0

exit_code=$(jq_read '
  (if .tool_response | type == "object" then .tool_response.exit_code else null end)
  // 0
')

case "$exit_code" in
'' | -* | *[!0-9]*) exit_code=0 ;;
esac

duration=$(jq_read '
  (if .tool_response | type == "object" then (.tool_response.duration_ms // .tool_response.duration) else null end)
  // 0
')

case "$duration" in
'' | *[!0-9]*) duration=0 ;;
esac

cwd=$(jq_read '.cwd // empty')
if [ -z "$cwd" ] || [ ! -d "$cwd" ]; then
  cwd="$HOME"
fi

(
  cd "$cwd" || exit 0

  export ATUIN_HISTORY_AUTHOR="codex"
  history_id=$(atuin history start -- "$bash_command") || exit 0
  atuin history end --exit "$exit_code" --duration "$duration" "$history_id"
) >/dev/null 2>&1

exit 0
