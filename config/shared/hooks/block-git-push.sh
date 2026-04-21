#!/usr/bin/env bash
# block-git-push.sh - Shared hook for Claude Code + Codex
# Blocks git push to main/master unless repo is in the allowlist.
# Exit 2 = block (Codex), JSON decision output (Claude).
set -euo pipefail

# --- Allowlist: repos where push to main/master is permitted ---
ALLOWED_REPOS=(
  "shunkakinoki/wiki"
  "shunkakinoki/gthq"
)

# Read tool input from stdin
input=$(cat)

# Extract command (works for both Claude and Codex input formats)
command=$(echo "$input" | jq -r '.tool_input.command // .command // empty' 2>/dev/null)
[[ -z $command ]] && exit 0

# Only check git push commands
if ! echo "$command" | grep -qE 'git\s+push'; then
  exit 0
fi

# Check if pushing to main or master
if ! echo "$command" | grep -qE '\b(main|master)\b'; then
  exit 0
fi

# Check repo allowlist (owner/repo from git remote)
repo=$(git remote get-url origin 2>/dev/null | sed -E 's#.*[:/]([^/]+/[^/]+)$#\1#; s#\.git$##' || echo "")
for allowed in "${ALLOWED_REPOS[@]}"; do
  if [[ $repo == "$allowed" ]]; then
    exit 0
  fi
done

# Block the push
msg="Push to main/master blocked in '$repo'. Use a feature branch + PR."
echo "BLOCKED by block-git-push.sh: $msg" >&2
exit 2
