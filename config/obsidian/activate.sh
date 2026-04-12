#!/usr/bin/env bash
# Copy obsidian config with home directory substitution
# Usage: activate.sh <config_json> <home_dir> <sed_bin>
set -euo pipefail
CONFIG_JSON="$1"
HOME_DIR="$2"
SED_BIN="$3"

OBS_DIR="$HOME_DIR/.config/obsidian"
mkdir -p "$OBS_DIR"

"$SED_BIN" "s|__HOME_DIR__|$HOME_DIR|g" "$CONFIG_JSON" >"$OBS_DIR/obsidian.json"

# Obsidian expects a per-vault config file named <vault-id>.json for each
# vault listed in obsidian.json. Seed any missing ones with an empty object
# so the daemon does not log ENOENT on every start.
python3 -c '
import json, sys, os
cfg = json.load(open(sys.argv[1]))
obs_dir = sys.argv[2]
for vid in cfg.get("vaults", {}):
    p = os.path.join(obs_dir, vid + ".json")
    if not os.path.exists(p):
        open(p, "w").write("{}")
' "$OBS_DIR/obsidian.json" "$OBS_DIR"
