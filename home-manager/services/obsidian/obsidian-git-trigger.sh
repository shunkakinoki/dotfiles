#!/usr/bin/env bash
# Commit, rebase, and push the memory wiki without depending on Obsidian's
# headless renderer or the obsidian-git community plugin.

set -euo pipefail

export PATH="@gh@/bin:@gitleaks@/bin:$HOME/.local/bin:$PATH"

VAULT="@vaultDir@"
GIT="@git@/bin/git"

if ! "$GIT" -C "$VAULT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "wiki-git-sync: vault is not a Git checkout: $VAULT" >&2
  exit 1
fi

BRANCH=$("$GIT" -C "$VAULT" symbolic-ref --short HEAD)
if [ "$BRANCH" != "main" ]; then
  echo "wiki-git-sync: expected main branch, found $BRANCH" >&2
  exit 1
fi

exec 9>"$VAULT/.git/wiki-sync.lock"
if ! @utilLinux@/bin/flock -n 9; then
  exit 0
fi

"$GIT" -C "$VAULT" add -A

if ! "$GIT" -C "$VAULT" diff --cached --quiet; then
  "$GIT" -C "$VAULT" -c commit.gpgsign=false commit -m "vault backup: $(@coreutils@/bin/date -u '+%Y-%m-%d %H:%M:%S UTC')"
fi

"$GIT" -C "$VAULT" fetch origin main
"$GIT" -C "$VAULT" rebase --autostash origin/main

if [ "$("$GIT" -C "$VAULT" rev-parse HEAD)" != "$("$GIT" -C "$VAULT" rev-parse origin/main)" ]; then
  "$GIT" -C "$VAULT" push origin HEAD:main
fi
