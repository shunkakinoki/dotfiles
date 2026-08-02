#!/usr/bin/env bash
# Copy nvim-pack-lock.json to nvim config directory
# Usage: activate-copy-pack-lock.sh <pack_lock_json>
set -euo pipefail
PACK_LOCK_JSON="$1"

mkdir -p "$HOME/.config/nvim"
# Remove any existing file/symlink first. `make neovim-dev`/`neovim-update`
# symlink this path back into the repo; without the rm, `cp -f` follows that
# symlink and writes through to the repo working tree, so every plugin change
# nvim makes shows up as an uncommitted diff. rm breaks the symlink so we get
# a plain local copy that nvim can dirty without touching the repo.
rm -f "$HOME/.config/nvim/nvim-pack-lock.json"
cp -f "$PACK_LOCK_JSON" "$HOME/.config/nvim/nvim-pack-lock.json"
chmod 644 "$HOME/.config/nvim/nvim-pack-lock.json"
