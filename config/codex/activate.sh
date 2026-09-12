#!/usr/bin/env bash
# Copy Codex config files, add optional live orchestration hooks, and synchronize
# managed Desktop settings.
# Usage: activate.sh <config_toml> <hooks_json> <desktop_settings_json> <jq_bin> <sync_script> <profiles_dir> [merge_hooks_script]
set -euo pipefail
CONFIG_TOML="$1"
HOOKS_JSON="$2"
DESKTOP_SETTINGS_JSON="$3"
JQ_BIN="$4"
SYNC_SCRIPT="$5"
PROFILES_DIR="$6"
MERGE_HOOKS_SCRIPT="${7:-$(dirname "${BASH_SOURCE[0]}")/merge-orchestration-hooks.sh}"

mkdir -p ~/.codex/hooks
for profile in "$PROFILES_DIR"/*.config.toml; do
  destination="$HOME/.codex/$(basename "$profile")"
  cp -f "$profile" "$destination"
  chmod 600 "$destination"
done
cp -f "$CONFIG_TOML" ~/.codex/config.toml
chmod 600 ~/.codex/config.toml
cp -f "$HOOKS_JSON" ~/.codex/hooks.json
chmod 644 ~/.codex/hooks.json

"$MERGE_HOOKS_SCRIPT" "$HOME/.codex/hooks.json" "$JQ_BIN"

"$SYNC_SCRIPT" "$DESKTOP_SETTINGS_JSON" "$JQ_BIN"
