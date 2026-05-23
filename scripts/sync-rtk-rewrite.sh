#!/usr/bin/env bash
# sync-rtk-rewrite.sh — check upstream rtk-rewrite.sh for drift.
#
# This repo's shared hook has local Copilot-format support (reads .toolArgs,
# emits .modifiedArgs) that upstream rtk-ai/rtk lacks. To protect those local
# additions, this script does not overwrite the shared copy — it fetches
# upstream and prints a diff so changes can be ported in manually.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
URL="https://raw.githubusercontent.com/rtk-ai/rtk/master/.claude/hooks/rtk-rewrite.sh"
SHARED="$ROOT/config/shared/hooks/rtk-rewrite.sh"

tmpfile=$(mktemp)
trap 'rm -f "$tmpfile"' EXIT

curl -fsSL "$URL" -o "$tmpfile"

if diff -q "$tmpfile" "$SHARED" >/dev/null; then
  echo "No drift from upstream."
  exit 0
fi

echo "Upstream drift detected (vs $SHARED):"
diff -u "$tmpfile" "$SHARED" || true
echo
echo "Shared copy has Copilot-format support not in upstream. Review the"
echo "diff above and port any non-Copilot changes into:"
echo "  config/shared/hooks/rtk-rewrite.sh"
