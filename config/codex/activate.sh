#!/usr/bin/env bash
# Copy Codex config files (atomic writes break symlinks)
# Usage: activate.sh <config_toml> <hooks_json>
set -euo pipefail
CONFIG_TOML="$1"
HOOKS_JSON="$2"

mkdir -p ~/.codex/hooks
cp -f "$CONFIG_TOML" ~/.codex/config.toml
chmod 600 ~/.codex/config.toml
cp -f "$HOOKS_JSON" ~/.codex/hooks.json
chmod 644 ~/.codex/hooks.json
