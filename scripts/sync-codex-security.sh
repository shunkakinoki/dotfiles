#!/usr/bin/env bash
# sync-codex-security.sh — Sync deny patterns from Claude settings.json
# into the shared security hook's hardcoded deny_patterns array.
# The shared hook is used by Codex, Copilot, and Cursor.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLAUDE_SETTINGS="$ROOT/config/claude/settings.json"
SHARED_SECURITY="$ROOT/config/shared/hooks/security.sh"

[[ -f $CLAUDE_SETTINGS ]] || {
  echo "ERROR: config/claude/settings.json not found" >&2
  exit 1
}

[[ -f $SHARED_SECURITY ]] || {
  echo "ERROR: config/shared/hooks/security.sh not found" >&2
  exit 1
}

# Extract Bash deny patterns and strip the Bash(...:*) wrapper
patterns=$(jq -r '.permissions.deny[]' "$CLAUDE_SETTINGS" |
  grep '^Bash(' |
  sed -E 's/^Bash\((.+):\*\)$/\1/' |
  sort)

# Write new array entries to a temp file
tmpfile=$(mktemp)
{
  echo "deny_patterns=("
  while IFS= read -r pat; do
    echo "  \"$pat\""
  done <<<"$patterns"
  echo ")"
} >"$tmpfile"

# Use sed to replace the block between deny_patterns=( and )
start_line=$(grep -n '^deny_patterns=(' "$SHARED_SECURITY" | head -1 | cut -d: -f1)
end_line=$(awk "NR>$start_line && /^\)/{print NR; exit}" "$SHARED_SECURITY")

if [[ -z $start_line ]] || [[ -z $end_line ]]; then
  echo "ERROR: Could not find deny_patterns block in $SHARED_SECURITY" >&2
  rm "$tmpfile"
  exit 1
fi

# Build the new file: head + new block + tail
{
  head -n "$((start_line - 1))" "$SHARED_SECURITY"
  cat "$tmpfile"
  tail -n "+$((end_line + 1))" "$SHARED_SECURITY"
} >"${SHARED_SECURITY}.tmp"

mv "${SHARED_SECURITY}.tmp" "$SHARED_SECURITY"
chmod +x "$SHARED_SECURITY"

rm "$tmpfile"
