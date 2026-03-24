#!/usr/bin/env bash
set -euo pipefail

for d in "$HOME"/.local/share/nvim/site/pack/*/opt/telescope-fzf-native.nvim \
  "$HOME"/.local/share/nvim/site/pack/*/start/telescope-fzf-native.nvim; do
  if [ -d "$d" ] && [ ! -f "$d/build/libfzf.so" ] && [ ! -f "$d/build/libfzf.dylib" ]; then
    echo "🔨 Building telescope-fzf-native.nvim..."
    make -C "$d" clean all
  fi
done
