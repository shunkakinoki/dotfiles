#!/usr/bin/env bash
# Merge declarative Antigravity CLI defaults into its writable settings file.
# The explicit Gemini provider requires GEMINI_API_KEY and bypasses Antigravity's
# authenticated default backend, so remove that legacy managed key on upgrade.
#
# Also merges the managed named hooks into the global customization root at
# ~/.gemini/config/hooks.json. That file is a shared merge point -- moshi-hook
# and orca write their own named hooks into it -- so merge rather than replace.
# Usage: activate.sh <managed-settings-json> <managed-hooks-json> [jq]
set -euo pipefail

MANAGED_SETTINGS="$1"
MANAGED_HOOKS="$2"
JQ="${3:-jq}"
SETTINGS_DIR="${HOME}/.gemini/antigravity-cli"
SETTINGS_FILE="${SETTINGS_DIR}/settings.json"
HOOKS_DIR="${HOME}/.gemini/config"
HOOKS_FILE="${HOOKS_DIR}/hooks.json"

mkdir -p "$SETTINGS_DIR"

if [ -f "$SETTINGS_FILE" ] && ! "$JQ" -e 'type == "object"' "$SETTINGS_FILE" >/dev/null; then
  echo "ERROR: refusing to replace invalid Antigravity settings: $SETTINGS_FILE" >&2
  exit 1
fi

tmp="$(mktemp "$SETTINGS_DIR/settings.json.XXXXXX")"
trap 'rm -f "$tmp"' EXIT

if [ -f "$SETTINGS_FILE" ]; then
  "$JQ" -s '.[0] * .[1] | del(.modelProvider)' "$SETTINGS_FILE" "$MANAGED_SETTINGS" >"$tmp"
else
  "$JQ" 'del(.modelProvider)' "$MANAGED_SETTINGS" >"$tmp"
fi

chmod 600 "$tmp"
mv -f "$tmp" "$SETTINGS_FILE"
trap - EXIT

mkdir -p "$HOOKS_DIR"

if [ -f "$HOOKS_FILE" ] && ! "$JQ" -e 'type == "object"' "$HOOKS_FILE" >/dev/null; then
  echo "ERROR: refusing to replace invalid Antigravity hooks: $HOOKS_FILE" >&2
  exit 1
fi

hooks_tmp="$(mktemp "$HOOKS_DIR/hooks.json.XXXXXX")"
trap 'rm -f "$hooks_tmp"' EXIT

if [ -f "$HOOKS_FILE" ]; then
  "$JQ" -s '.[0] * .[1]' "$HOOKS_FILE" "$MANAGED_HOOKS" >"$hooks_tmp"
else
  "$JQ" '.' "$MANAGED_HOOKS" >"$hooks_tmp"
fi

chmod 644 "$hooks_tmp"
mv -f "$hooks_tmp" "$HOOKS_FILE"
trap - EXIT
