#!/usr/bin/env bash

# Claude Code's Bash tool runs non-interactively, so Atuin's shell hooks never see it.
# Record completed Bash tool commands through Atuin's start/end API instead.

hook_input=$(cat)

[ -n "$hook_input" ] || exit 0

if ! command -v atuin >/dev/null 2>&1 || ! command -v jq >/dev/null 2>&1; then
  exit 0
fi

jq_read() {
  jq -r "$1" <<<"$hook_input"
}

tool_name=$(jq_read '
  .tool_name // .tool.name // empty
')

[ "$tool_name" = "Bash" ] || exit 0

bash_command=$(jq_read '
  def maybe_string: if type == "string" then . else empty end;
  .tool_input.command
  // .tool.input.command
  // (.tool_input | maybe_string)
  // (.tool.input | maybe_string)
  // empty
')

[ -n "$bash_command" ] || exit 0

run_in_background=$(jq_read '
  .tool_input.run_in_background
  // .tool.input.run_in_background
  // false
')

[ "$run_in_background" = "true" ] && exit 0

exit_code=$(jq_read '
  (if .tool_result  | type == "object" then .tool_result.exit_code  else null end)
  // (if .tool_response | type == "object" then .tool_response.exit_code else null end)
  // (if .response     | type == "object" then .response.exit_code     else null end)
  // 0
')

case "$exit_code" in
'' | -* | *[!0-9]*) exit_code=0 ;;
esac

duration=$(jq_read '
  (if .tool_result  | type == "object" then (.tool_result.duration_ms  // .tool_result.duration)  else null end)
  // (if .tool_response | type == "object" then (.tool_response.duration_ms // .tool_response.duration) else null end)
  // (if .response     | type == "object" then (.response.duration_ms     // .response.duration)     else null end)
  // 0
')

case "$duration" in
'' | *[!0-9]*) duration=0 ;;
esac

cwd=$(jq_read '.cwd // empty')
if [ -z "$cwd" ] || [ ! -d "$cwd" ]; then
  cwd="$HOME"
fi

description=$(jq_read '
  def maybe_string: if type == "string" then . else empty end;
  .tool_input.description
  // .tool.input.description
  // empty
')

(
  cd "$cwd" || exit 0

  export ATUIN_HISTORY_AUTHOR="claude"
  if [ -n "$description" ]; then
    export ATUIN_HISTORY_INTENT="$description"
  fi

  history_id=$(atuin history start -- "$bash_command") || exit 0
  atuin history end --exit "$exit_code" --duration "$duration" "$history_id"
) >/dev/null 2>&1

exit 0
