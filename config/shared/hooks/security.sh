#!/usr/bin/env bash

# Shared Codex/Copilot/Cursor/Grok Security Hook
# Blocks dangerous Bash commands by checking against deny patterns.
# Returns exit code 2 to block, exit code 0 to allow.
#
# Claude has its own settings.json-driven security.sh — this is for the
# agents that don't read settings.json at runtime.
#
# Cursor on macOS launches GUI apps with a minimal PATH, so this script
# self-bootstraps PATH to find jq.

export PATH="$HOME/.cargo/bin:/etc/profiles/per-user/shunkakinoki/bin:/run/current-system/sw/bin:/nix/var/nix/profiles/default/bin:/opt/homebrew/bin:/usr/local/bin:/usr/sbin:/usr/bin:/bin:${PATH:-}"

set -euo pipefail

# Fail closed: a security hook that can't parse its input must block, not allow.
if ! command -v jq >/dev/null 2>&1; then
  echo "BLOCKED by security.sh: jq not available, cannot evaluate command safely" >&2
  exit 2
fi

input=$(cat)

# Only process shell commands when the hook input includes a tool name.
# Cursor sends only .command without a tool_name → empty passes through.
tool_name=$(echo "$input" | jq -r '.tool.name // .tool_name // .toolName // empty' 2>/dev/null)
case "$tool_name" in
"" | Bash | bash | shell) ;;
*) exit 0 ;;
esac

# Extract command across Claude/Codex/Copilot/Cursor input shapes.
command=$(echo "$input" | jq -r '
  .command
  // .tool.input.command
  // .tool_input.command
  // (.toolArgs | if type == "object" then .command else empty end)
  // (.toolArgs | if type == "string" then (fromjson? | .command) else empty end)
  // .toolInput.command
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
  # Pure-bash trim avoids xargs interpreting quotes/backslashes in the deny list
  segment="${segment#"${segment%%[![:space:]]*}"}"
  segment="${segment%"${segment##*[![:space:]]}"}"
  [[ -z $segment ]] && continue

  for pattern in "${deny_patterns[@]}"; do
    if [[ $segment == $pattern* ]]; then
      echo "BLOCKED by security.sh: Command '$segment' matches deny pattern '$pattern'" >&2
      exit 2
    fi
  done
done

exit 0
