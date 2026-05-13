#!/usr/bin/env bash
# Copy dcg config (atomic writes break symlinks)
# Usage: activate.sh <config_toml>
set -euo pipefail
CONFIG_TOML="$1"

mkdir -p ~/.config/dcg/packs
cp -f "$CONFIG_TOML" ~/.config/dcg/config.toml
chmod 644 ~/.config/dcg/config.toml
