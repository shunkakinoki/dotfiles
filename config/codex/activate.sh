#!/usr/bin/env bash
# Copy Codex config files and synchronize managed Desktop settings.
# Usage: activate.sh <config_toml> <hooks_json> <desktop_settings_json> <jq_bin> <sync_script>
set -euo pipefail
CONFIG_TOML="$1"
HOOKS_JSON="$2"
DESKTOP_SETTINGS_JSON="$3"
JQ_BIN="$4"
SYNC_SCRIPT="$5"

mkdir -p ~/.codex/hooks
cp -f "$CONFIG_TOML" ~/.codex/config.toml
chmod 600 ~/.codex/config.toml
cp -f "$HOOKS_JSON" ~/.codex/hooks.json
chmod 644 ~/.codex/hooks.json

"$SYNC_SCRIPT" "$DESKTOP_SETTINGS_JSON" "$JQ_BIN"
