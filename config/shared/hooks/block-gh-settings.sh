#!/usr/bin/env bash
# block-gh-settings.sh — Shared hook for Claude Code + Codex + Copilot + Cursor
# Blocks gh CLI commands that modify GitHub repository settings.
# Exit 2 = block; works across all four agent hook protocols.

# Cursor on macOS launches GUI apps with a minimal PATH; self-bootstrap it
# so jq/gh are findable regardless of caller.
export PATH="$HOME/.cargo/bin:/etc/profiles/per-user/shunkakinoki/bin:/run/current-system/sw/bin:/nix/var/nix/profiles/default/bin:/opt/homebrew/bin:/usr/local/bin:/usr/sbin:/usr/bin:/bin:${PATH:-}"

set -euo pipefail

# Read tool input from stdin
input=$(cat)

# Extract command (works for Claude, Codex, and Copilot hook input formats)
command=$(echo "$input" | jq -r '.tool.input.command // .tool_input.command // .toolArgs.command // .toolInput.command // .command // empty' 2>/dev/null)
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
