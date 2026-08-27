#!/usr/bin/env bash
# Merge declarative Antigravity CLI defaults into its writable settings file.
# The explicit Gemini provider requires GEMINI_API_KEY and bypasses Antigravity's
# authenticated default backend, so remove that legacy managed key on upgrade.
#
# Also installs the managed named hooks into the global customization root at
# ~/.gemini/config/hooks.json. Every hook there is declared here, including the
# ones moshi-hook and orca install themselves, so this replaces the file rather
# than merging into whatever those installers last wrote.
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

# Copied rather than symlinked: moshi-hook and orca rewrite this file on their
# own install, and a store symlink would make them fail instead of simply being
# reverted on the next switch.
cp -f "$MANAGED_HOOKS" "$HOOKS_FILE"
chmod 644 "$HOOKS_FILE"
