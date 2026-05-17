#!/usr/bin/env bash

# Codex/Copilot Security Hook
# Blocks dangerous Bash commands by checking against deny patterns.
# Returns exit code 2 to block, exit code 0 to allow.

set -euo pipefail

input=$(cat)

# Only process shell commands when the hook input includes a tool name.
tool_name=$(echo "$input" | jq -r '.tool.name // .tool_name // .toolName // empty' 2>/dev/null)
case "$tool_name" in
"" | Bash | bash | shell) ;;
*) exit 0 ;;
esac

command=$(echo "$input" | jq -r '
  .tool.input.command
  // .tool_input.command
  // (.toolArgs | if type == "object" then .command else empty end)
  // (.toolArgs | if type == "string" then (fromjson? | .command) else empty end)
  // .toolInput.command
  // .command
  // empty
' 2>/dev/null)
[[ -z $command ]] && exit 0

# Hardcoded deny patterns (mirrors claude settings.json deny list)
deny_patterns=(
  "chmod -R 777"
  "dd if="
  "docker system prune -a"
  "docker system prune -f"
  "git push --force origin main"
  "git push --force origin master"
  "git push --force-with-lease origin main"
  "git push --force-with-lease origin master"
  "git push -f origin main"
  "git push -f origin master"
  "mkfs"
  "rm -rf /*"
  "rm -rf ~/*"
  "sudo"
)

# Split command at logical operators
IFS=$'\n' read -r -d '' -a segments < <(echo "$command" | sed -E 's/[;&|]+/\n/g' && printf '\0') || true

for segment in "${segments[@]}"; do
  segment=$(echo "$segment" | xargs 2>/dev/null) || continue
  [[ -z $segment ]] && continue

  for pattern in "${deny_patterns[@]}"; do
    if [[ $segment == $pattern* ]]; then
      echo "BLOCKED by security.sh: Command '$segment' matches deny pattern '$pattern'" >&2
      exit 2
    fi
  done
done

exit 0
