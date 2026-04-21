#!/usr/bin/env bash
# block-gh-settings.sh — Shared hook for Claude Code + Codex
# Blocks gh CLI commands that modify GitHub repository settings.
# Exit 2 = block (Codex), JSON decision output (Claude).
set -euo pipefail

# Read tool input from stdin
input=$(cat)

# Extract command
command=$(echo "$input" | jq -r '.tool_input.command // .command // empty' 2>/dev/null)
[[ -z $command ]] && exit 0

# Block: gh repo <destructive-subcommand>
if echo "$command" | grep -qE 'gh\s+repo\s+(delete|rename|archive|transfer|edit)\b'; then
  subcommand=$(echo "$command" | grep -oE 'gh\s+repo\s+(delete|rename|archive|transfer|edit)' | awk '{print $3}')
  msg="'gh repo $subcommand' is blocked. Repo settings must be changed manually."
  echo "BLOCKED by block-gh-settings.sh: $msg" >&2
  exit 2
fi

# Block: gh api -X PATCH|DELETE|PUT targeting /repos/
if echo "$command" | grep -qE 'gh\s+api'; then
  if echo "$command" | grep -qE '\-X\s+(PATCH|DELETE|PUT)' && echo "$command" | grep -qE '/repos/'; then
    method=$(echo "$command" | grep -oE '\-X\s+(PATCH|DELETE|PUT)' | awk '{print $2}')
    msg="'gh api -X $method /repos/...' is blocked. Repo API mutations must be done manually."
    echo "BLOCKED by block-gh-settings.sh: $msg" >&2
    exit 2
  fi
fi

exit 0
