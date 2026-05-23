#!/usr/bin/env bash

# Cursor Security Hook (beforeShellExecution)
# Blocks dangerous Bash commands by checking against deny patterns.
# Mirrors codex/copilot security.sh; Cursor sends `command` at top level.
# Returns exit code 2 to block, exit code 0 to allow.

export PATH="$HOME/.cargo/bin:/etc/profiles/per-user/shunkakinoki/bin:/run/current-system/sw/bin:/nix/var/nix/profiles/default/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:${PATH:-}"

set -euo pipefail

command -v jq >/dev/null 2>&1 || exit 0

input=$(cat)

command=$(echo "$input" | jq -r '
  .command
  // .tool.input.command
  // .tool_input.command
  // empty
' 2>/dev/null)
[[ -z $command ]] && exit 0

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

IFS=$'\n' read -r -d '' -a segments < <(echo "$command" | sed -E 's/[;&|]+/\n/g' && printf '\0') || true

for segment in "${segments[@]}"; do
  segment=$(echo "$segment" | xargs 2>/dev/null) || continue
  [[ -z $segment ]] && continue

  for pattern in "${deny_patterns[@]}"; do
    if [[ $segment == $pattern* ]]; then
      jq -n --arg msg "Command '$segment' matches deny pattern '$pattern'" \
        '{permission: "deny", user_message: $msg, agent_message: $msg}'
      exit 2
    fi
  done
done

exit 0
