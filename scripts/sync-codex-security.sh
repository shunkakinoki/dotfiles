#!/usr/bin/env bash
# sync-codex-security.sh — Sync deny patterns from Claude settings.json
# into the Codex security hook's hardcoded deny_patterns array.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLAUDE_SETTINGS="$ROOT/config/claude/settings.json"
CODEX_SECURITY="$ROOT/config/codex/hooks/security.sh"

[[ -f $CLAUDE_SETTINGS ]] || {
  echo "ERROR: config/claude/settings.json not found" >&2
  exit 1
}

[[ -f $CODEX_SECURITY ]] || {
  echo "ERROR: config/codex/hooks/security.sh not found" >&2
  exit 1
}

# Extract Bash deny patterns and strip the Bash(...:*) wrapper
patterns=$(jq -r '.permissions.deny[]' "$CLAUDE_SETTINGS" \
  | grep '^Bash(' \
  | sed -E 's/^Bash\((.+):\*\)$/\1/' \
  | sort)

# Build the replacement file using sed to replace the block
tmpfile=$(mktemp)

# Write new array entries to a temp file
{
  echo "deny_patterns=("
  while IFS= read -r pat; do
    echo "  \"$pat\""
  done <<<"$patterns"
  echo ")"
} >"$tmpfile"

# Use sed to replace the block between deny_patterns=( and )
# First, get line numbers
start_line=$(grep -n '^deny_patterns=(' "$CODEX_SECURITY" | head -1 | cut -d: -f1)
end_line=$(awk "NR>$start_line && /^\)/{print NR; exit}" "$CODEX_SECURITY")

if [[ -z $start_line ]] || [[ -z $end_line ]]; then
  echo "ERROR: Could not find deny_patterns block in $CODEX_SECURITY" >&2
  rm "$tmpfile"
  exit 1
fi

# Build the new file: head + new block + tail
{
  head -n "$((start_line - 1))" "$CODEX_SECURITY"
  cat "$tmpfile"
  tail -n "+$((end_line + 1))" "$CODEX_SECURITY"
} >"${CODEX_SECURITY}.tmp"

mv "${CODEX_SECURITY}.tmp" "$CODEX_SECURITY"
chmod +x "$CODEX_SECURITY"
rm "$tmpfile"
