#!/usr/bin/env bash
# shellcheck disable=SC2016
# Copy Codex config files and merge managed Desktop settings.
# Usage: activate.sh <config_toml> <hooks_json> <desktop_settings_json> <jq_bin>
set -euo pipefail
CONFIG_TOML="$1"
HOOKS_JSON="$2"
DESKTOP_SETTINGS_JSON="$3"
JQ_BIN="$4"
GLOBAL_STATE="$HOME/.codex/.codex-global-state.json"

mkdir -p ~/.codex/hooks
cp -f "$CONFIG_TOML" ~/.codex/config.toml
chmod 600 ~/.codex/config.toml
cp -f "$HOOKS_JSON" ~/.codex/hooks.json
chmod 644 ~/.codex/hooks.json

# Git and worktree preferences use Codex Desktop's global-state store rather
# than config.toml. Merge only the managed keys so task and UI state survive.
GLOBAL_STATE_TMP=$(mktemp "${GLOBAL_STATE}.tmp.XXXXXX")
trap 'rm -f "$GLOBAL_STATE_TMP"' EXIT

if [[ -s $GLOBAL_STATE ]]; then
  "$JQ_BIN" --slurpfile settings "$DESKTOP_SETTINGS_JSON" '
    .["electron-persisted-atom-state"] =
      ((.["electron-persisted-atom-state"] // {}) + $settings[0])
  ' "$GLOBAL_STATE" >"$GLOBAL_STATE_TMP"
else
  "$JQ_BIN" -n --slurpfile settings "$DESKTOP_SETTINGS_JSON" '
    {"electron-persisted-atom-state": $settings[0]}
  ' >"$GLOBAL_STATE_TMP"
fi

chmod 600 "$GLOBAL_STATE_TMP"
mv -f "$GLOBAL_STATE_TMP" "$GLOBAL_STATE"
trap - EXIT
