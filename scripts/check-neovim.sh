#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
NVIM_CONFIG="$ROOT_DIR/home-manager/programs/neovim/init.lua"

echo "🔍 Checking Neovim configuration..."

if ! command -v nvim >/dev/null 2>&1; then
	echo "⚠️  Neovim is not installed or not in PATH"
	exit 1
fi

if [ ! -f "$NVIM_CONFIG" ]; then
	echo "⚠️  Could not find Neovim configuration at $NVIM_CONFIG"
	exit 1
fi

echo "📝 Validating Neovim configuration syntax..."
mkdir -p ~/.config/nvim

if [ -L "$HOME/.config/nvim/lua" ] || [ -d "$HOME/.config/nvim/lua" ]; then
	rm -rf "$HOME/.config/nvim/lua"
fi

ln -sf "$ROOT_DIR/home-manager/programs/neovim/init.lua" ~/.config/nvim/init.lua
ln -sf "$ROOT_DIR/home-manager/programs/neovim/lua" ~/.config/nvim/lua

if [ -f "$ROOT_DIR/home-manager/programs/neovim/nvim-pack-lock.json" ]; then
	ln -sf "$ROOT_DIR/home-manager/programs/neovim/nvim-pack-lock.json" ~/.config/nvim/nvim-pack-lock.json
fi

echo "📦 Installing plugins..."
nvim --headless +"lua vim.pack.update()" +qa 2>&1

for d in "$HOME"/.local/share/nvim/site/pack/*/opt/telescope-fzf-native.nvim \
         "$HOME"/.local/share/nvim/site/pack/*/start/telescope-fzf-native.nvim; do
	if [ -d "$d" ] && [ ! -f "$d/build/libfzf.so" ] && [ ! -f "$d/build/libfzf.dylib" ]; then
		echo "🔨 Building telescope-fzf-native.nvim..."
		make -C "$d" clean all
	fi
done

nvim --headless -c "lua dofile('$NVIM_CONFIG')" -c "qa" 2>&1 | tee /tmp/nvim-check.log

if grep -q "^E[0-9]\|^Error\|module .* not found" /tmp/nvim-check.log; then
	echo "❌ Neovim configuration has errors"
	exit 1
fi

echo "✅ Neovim configuration is valid"
