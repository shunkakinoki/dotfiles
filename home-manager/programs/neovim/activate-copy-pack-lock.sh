#!/usr/bin/env bash
# Copy nvim-pack-lock.json to nvim config directory
# Usage: activate-copy-pack-lock.sh <pack_lock_json>
set -euo pipefail
PACK_LOCK_JSON="$1"

mkdir -p "$HOME/.config/nvim"
cp -f "$PACK_LOCK_JSON" "$HOME/.config/nvim/nvim-pack-lock.json"
chmod 644 "$HOME/.config/nvim/nvim-pack-lock.json"
