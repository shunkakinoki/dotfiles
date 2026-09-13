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

# Codex records directory trust ([projects.*]) and hook trust ([hooks.state.*])
# in the same files this script replaces. Carry those tables into the new copy
# so activation does not revoke trust and stall every session at a prompt.
TRUST_TABLE_PATTERN='^[[:space:]]*\[(projects\.|hooks\.state[].])'
install_config() {
  local source="$1" destination="$2" preserved="" keep=0 line
  if [[ -f $destination ]]; then
    while IFS= read -r line || [[ -n $line ]]; do
      if [[ $line =~ ^[[:space:]]*\[ ]]; then
        if [[ $line =~ $TRUST_TABLE_PATTERN ]]; then keep=1; else keep=0; fi
      fi
      if ((keep)); then preserved+="$line"$'\n'; fi
    done <"$destination"
  fi
  cp -f "$source" "$destination"
  chmod 600 "$destination"
  if [[ -n $preserved ]]; then
    printf '\n%s' "$preserved" >>"$destination"
  fi
}

mkdir -p ~/.codex/hooks
for profile in "$PROFILES_DIR"/*.config.toml; do
  install_config "$profile" "$HOME/.codex/$(basename "$profile")"
done
install_config "$CONFIG_TOML" ~/.codex/config.toml
cp -f "$HOOKS_JSON" ~/.codex/hooks.json
chmod 644 ~/.codex/hooks.json

"$MERGE_HOOKS_SCRIPT" "$HOME/.codex/hooks.json" "$JQ_BIN"

"$SYNC_SCRIPT" "$DESKTOP_SETTINGS_JSON" "$JQ_BIN"
