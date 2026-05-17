#!/usr/bin/env bash
# sync-rtk-rewrite.sh — Sync rtk-rewrite.sh from upstream rtk repo via raw GitHub.
#
# After fetching upstream, applies scripts/rtk-rewrite.copilot.patch so the
# local Copilot-format support (reads .toolArgs, emits .modifiedArgs) survives
# the sync. If you upstream the patch to rtk-ai/rtk, delete the patch file and
# the apply step here.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
URL="https://raw.githubusercontent.com/rtk-ai/rtk/master/.claude/hooks/rtk-rewrite.sh"
PATCH="$ROOT/scripts/rtk-rewrite.copilot.patch"

tmpfile=$(mktemp)
trap 'rm -f "$tmpfile"' EXIT

curl -fsSL "$URL" -o "$tmpfile"

if [ -f "$PATCH" ]; then
  patch "$tmpfile" <"$PATCH"
fi

cp "$tmpfile" "$ROOT/config/claude/hooks/rtk-rewrite.sh"
cp "$tmpfile" "$ROOT/config/codex/hooks/rtk-rewrite.sh"
cp "$tmpfile" "$ROOT/config/copilot/hooks/rtk-rewrite.sh"
