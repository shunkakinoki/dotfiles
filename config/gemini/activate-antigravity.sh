#!/usr/bin/env bash
# Merge managed permissions into antigravity-cli's settings.json.
# The agy binary reads ~/.gemini/antigravity-cli/settings.json, but CCS
# hydration writes permissions to ~/.ccs/agy.settings.json. This script
# bridges the gap by merging the permissions block.
# Usage: activate-antigravity.sh <jq_bin>
set -euo pipefail

JQ_BIN="$1"
CCS_SETTINGS="${HOME}/.ccs/agy.settings.json"
AGY_DIR="${HOME}/.gemini/antigravity-cli"
AGY_SETTINGS="${AGY_DIR}/settings.json"

if [ ! -f "$CCS_SETTINGS" ]; then
  exit 0
fi

PERMS=$("$JQ_BIN" -c '.permissions // empty' "$CCS_SETTINGS" 2>/dev/null) || true
if [ -z "$PERMS" ]; then
  exit 0
fi

mkdir -p "$AGY_DIR"

TEMP_SETTINGS=""
cleanup() {
  if [ -n "$TEMP_SETTINGS" ]; then
    rm -f "$TEMP_SETTINGS"
  fi
}
trap cleanup EXIT

TEMP_SETTINGS="$(mktemp "$AGY_DIR/settings.json.XXXXXX")"

if [ -f "$AGY_SETTINGS" ]; then
  "$JQ_BIN" --argjson perms "$PERMS" '.permissions = $perms' "$AGY_SETTINGS" >"$TEMP_SETTINGS"
else
  "$JQ_BIN" -n --argjson perms "$PERMS" '{permissions: $perms}' >"$TEMP_SETTINGS"
fi

mv -f "$TEMP_SETTINGS" "$AGY_SETTINGS"
TEMP_SETTINGS=""
chmod 600 "$AGY_SETTINGS"
