#!/usr/bin/env bash
# Merge declarative Antigravity CLI defaults into its writable settings file.
# Usage: activate.sh <managed-settings-json> [jq]
set -euo pipefail

MANAGED_SETTINGS="$1"
JQ="${2:-jq}"
SETTINGS_DIR="${HOME}/.gemini/antigravity-cli"
SETTINGS_FILE="${SETTINGS_DIR}/settings.json"

mkdir -p "$SETTINGS_DIR"

if [ -f "$SETTINGS_FILE" ] && ! "$JQ" -e 'type == "object"' "$SETTINGS_FILE" >/dev/null; then
  echo "ERROR: refusing to replace invalid Antigravity settings: $SETTINGS_FILE" >&2
  exit 1
fi

tmp="$(mktemp "$SETTINGS_DIR/settings.json.XXXXXX")"
trap 'rm -f "$tmp"' EXIT

if [ -f "$SETTINGS_FILE" ]; then
  "$JQ" -s '.[0] * .[1]' "$SETTINGS_FILE" "$MANAGED_SETTINGS" >"$tmp"
else
  "$JQ" '.' "$MANAGED_SETTINGS" >"$tmp"
fi

chmod 644 "$tmp"
mv -f "$tmp" "$SETTINGS_FILE"
trap - EXIT
