#!/usr/bin/env bash
# sync-rtk-rewrite.sh — check upstream rtk-rewrite.sh for drift.
#
# This repo's hook copies have local Copilot-format support (reads .toolArgs,
# emits .modifiedArgs) that upstream rtk-ai/rtk lacks. To protect those local
# additions, this script no longer overwrites the local copies — it just
# fetches upstream and prints a diff so changes can be ported in manually.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
URL="https://raw.githubusercontent.com/rtk-ai/rtk/master/.claude/hooks/rtk-rewrite.sh"

tmpfile=$(mktemp)
trap 'rm -f "$tmpfile"' EXIT

curl -fsSL "$URL" -o "$tmpfile"

if diff -q "$tmpfile" "$ROOT/config/claude/hooks/rtk-rewrite.sh" >/dev/null; then
  echo "No drift from upstream."
  exit 0
fi

echo "Upstream drift detected (vs config/claude/hooks/rtk-rewrite.sh):"
diff -u "$tmpfile" "$ROOT/config/claude/hooks/rtk-rewrite.sh" || true
echo
echo "Local copies have Copilot-format support not in upstream. Review the"
echo "diff above and port any non-Copilot changes into all three hook files:"
echo "  config/claude/hooks/rtk-rewrite.sh"
echo "  config/codex/hooks/rtk-rewrite.sh"
echo "  config/copilot/hooks/rtk-rewrite.sh"
