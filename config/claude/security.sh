#!/usr/bin/env bash

# Claude Code Security Hook
# Blocks dangerous Bash commands by checking against deny patterns
# Based on: https://wasabeef.jp/blog/claude-code-secure-bash
#
# This script runs as a PreToolUse hook and returns:
# - Exit code 0: Command is allowed
# - Exit code 2: Command is blocked

set -euo pipefail

# Read JSON input from stdin
input=$(cat)

# Extract tool name - only process Bash commands
tool_name=$(echo "$input" | jq -r '.tool.name // empty' 2>/dev/null)
[[ $tool_name != "Bash" ]] && exit 0

# Extract the command to be executed
command=$(echo "$input" | jq -r '.tool.input.command // empty' 2>/dev/null)
[[ -z $command ]] && exit 0

# Path to settings file with deny patterns
settings="$HOME/.claude/settings.json"
[[ ! -f $settings ]] && exit 0

# Read deny patterns from settings
mapfile -t deny_patterns < <(jq -r '.permissions.deny[]?' "$settings" 2>/dev/null)

# Function to check if a command matches a pattern
# Supports glob-style wildcards
matches_pattern() {
  local cmd="$1"
  local pattern="$2"

  # Extract pattern from Bash(...) format
  if [[ $pattern =~ ^Bash\((.+)\)$ ]]; then
    local check_pattern="${BASH_REMATCH[1]}"
    # Convert legacy trailing :* into a prefix glob (e.g. sudo:* -> sudo*)
    if [[ $check_pattern == *':*' ]]; then
      check_pattern="${check_pattern%:*}*"
    fi

    # Use bash glob matching (extended globbing)
    shopt -s extglob
    # shellcheck disable=SC2053
    if [[ $cmd == $check_pattern ]]; then
      return 0
    fi
    shopt -u extglob
  fi
  return 1
}

# Split command at logical operators to catch hidden dangerous commands
# This handles: cmd1 ; cmd2, cmd1 && cmd2, cmd1 || cmd2, cmd1 | cmd2
IFS=$'\n' read -r -d '' -a segments < <(echo "$command" | sed -E 's/[;&|]+/\n/g' && printf '\0') || true

for segment in "${segments[@]}"; do
  # Trim leading/trailing whitespace
  segment=$(echo "$segment" | xargs 2>/dev/null) || continue
  [[ -z $segment ]] && continue

  for pattern in "${deny_patterns[@]}"; do
    if matches_pattern "$segment" "$pattern"; then
      echo "BLOCKED by security.sh: Command '$segment' matches deny pattern '$pattern'" >&2
      exit 2
    fi
  done
done

# Command passed all checks
exit 0
