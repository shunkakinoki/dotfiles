#!/usr/bin/env bash
# Create /bin shell symlinks on non-NixOS Linux systems
# Usage: activate.sh <bash_path> <fish_path> <zsh_path>
set -euo pipefail
BASH_PATH="$1"
FISH_PATH="$2"
ZSH_PATH="$3"

# Skip on NixOS - /bin symlinks are managed at the system level
if [ -f /etc/NIXOS ]; then
  echo "Skipping /bin shell symlinks on NixOS (managed by system configuration)"
  exit 0
fi

SUDO_CMD=""
if command -v sudo >/dev/null 2>&1; then
  SUDO_CMD="sudo"
elif [ -x /run/wrappers/bin/sudo ]; then
  SUDO_CMD="/run/wrappers/bin/sudo"
elif [ -x /usr/bin/sudo ]; then
  SUDO_CMD="/usr/bin/sudo"
elif [ "$(id -u)" -ne 0 ]; then
  echo "Creating /bin shell symlinks requires root privileges, but sudo is not available." >&2
  exit 1
fi

run_root_cmd() {
  if [ -n "$SUDO_CMD" ]; then
    "$SUDO_CMD" "$@"
  else
    "$@"
  fi
}

run_root_cmd mkdir -p /bin
run_root_cmd ln -sf "$BASH_PATH" /bin/bash
run_root_cmd ln -sf "$FISH_PATH" /bin/fish
run_root_cmd ln -sf "$ZSH_PATH" /bin/zsh
