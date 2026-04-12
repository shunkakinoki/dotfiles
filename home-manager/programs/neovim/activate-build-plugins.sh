#!/usr/bin/env bash
# Build native Neovim plugins (telescope-fzf-native, fff.nvim, vscode-diff)
# Usage: activate-build-plugins.sh <pack_dir> <lib_ext>
set -euo pipefail
PACK_DIR="$1"
LIB_EXT="$2"

# --- telescope-fzf-native.nvim (C build) ---
fzf_dir=""
for d in "$PACK_DIR"/*/opt/telescope-fzf-native.nvim "$PACK_DIR"/*/start/telescope-fzf-native.nvim; do
  if [ -d "$d" ]; then
    fzf_dir="$d"
    break
  fi
done
if [ -n "$fzf_dir" ] && [ ! -f "$fzf_dir/build/libfzf.${LIB_EXT}" ]; then
  echo "Building telescope-fzf-native.nvim in $fzf_dir..."
  make -C "$fzf_dir" clean all
fi

# --- fff.nvim (Rust, download prebuilt binary from GitHub releases) ---
fff_dir=""
for d in "$PACK_DIR"/*/opt/fff.nvim "$PACK_DIR"/*/start/fff.nvim; do
  if [ -d "$d" ]; then
    fff_dir="$d"
    break
  fi
done
if [ -n "$fff_dir" ]; then
  fff_binary="$fff_dir/target/libfff_nvim.${LIB_EXT}"
  if [ ! -f "$fff_binary" ]; then
    echo "Downloading fff.nvim native binary..."
    fff_version=$(git -C "$fff_dir" rev-parse --short HEAD 2>/dev/null || echo "")
    if [ -n "$fff_version" ]; then
      _arch=$(uname -m)
      _ldd=$(ldd --version 2>&1 || echo "")
      if echo "$_ldd" | grep -q musl; then
        _triple="${_arch}-unknown-linux-musl"
      else
        _triple="${_arch}-unknown-linux-gnu"
      fi
      mkdir -p "$fff_dir/target"
      echo "Fetching https://github.com/dmtrKovalenko/fff.nvim/releases/download/$fff_version/${_triple}.${LIB_EXT}"
      curl --fail --location --silent --show-error \
        -o "$fff_binary" \
        "https://github.com/dmtrKovalenko/fff.nvim/releases/download/$fff_version/${_triple}.${LIB_EXT}" &&
        echo "fff.nvim binary downloaded successfully" ||
        echo "fff.nvim binary download failed (will fall back to build on first use)"
    else
      echo "fff.nvim: could not determine version, skipping download"
    fi
  fi
fi

# --- vscode-diff.nvim (C build via build.sh) ---
vsd_dir=""
for d in "$PACK_DIR"/*/opt/vscode-diff.nvim "$PACK_DIR"/*/start/vscode-diff.nvim; do
  if [ -d "$d" ]; then
    vsd_dir="$d"
    break
  fi
done
if [ -n "$vsd_dir" ]; then
  if ! ls "$vsd_dir"/libvscode_diff*."${LIB_EXT}" 1>/dev/null 2>&1; then
    echo "Building vscode-diff.nvim native library..."
    bash "$vsd_dir/build.sh" && echo "vscode-diff.nvim built successfully" ||
      echo "vscode-diff.nvim build failed"
  fi
fi
