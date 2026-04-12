#!/usr/bin/env bash
# Copy obsidian config with home directory substitution
# Usage: activate.sh <config_json> <home_dir> <sed_bin>
set -euo pipefail
CONFIG_JSON="$1"
HOME_DIR="$2"
SED_BIN="$3"

mkdir -p "$HOME_DIR/.config/obsidian"
"$SED_BIN" "s|__HOME_DIR__|$HOME_DIR|g" "$CONFIG_JSON" >"$HOME_DIR/.config/obsidian/obsidian.json"
chmod 644 "$HOME_DIR/.config/obsidian/obsidian.json"
