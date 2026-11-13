#!/usr/bin/env bash
# Claude Desktop auto-trusts a hook-created worktree only when the WorktreeCreate
# hook comes from a settings tier a repository cannot commit; a repo-committed
# hook leaves every worktree untrusted, so sessions that share one fail to start.
# Repos that ship scripts/claude-worktree.ts keep their own worktree layout.
set -euo pipefail

input=$(cat)
cwd=$(jq -r '.cwd // empty' <<<"$input")
name=$(jq -r '.name // empty' <<<"$input")
cwd=${cwd:-$PWD}

if [ -z "$name" ]; then
  echo "worktree-create: hook input has no name" >&2
  exit 2
fi

top=$(git -C "$cwd" rev-parse --show-toplevel)
if [ -f "$top/scripts/claude-worktree.ts" ]; then
  cd "$top"
  printf '%s' "$input" | exec bun --no-install "$top/scripts/claude-worktree.ts"
fi

root=$(dirname "$(git -C "$cwd" rev-parse --path-format=absolute --git-common-dir)")
path="$root/.claude/worktrees/$name"
git -C "$root" worktree add -q -b "claude/$name" "$path" HEAD >&2
printf '%s\n' "$path"
