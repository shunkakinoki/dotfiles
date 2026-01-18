#!/usr/bin/env bash

set -euo pipefail

# Export HOST for Nix impure builds (used by lib/host.nix to detect kyber/galactica)
# This is needed because systemd doesn't inherit the shell environment
export HOST="${HOST:-$(/usr/bin/hostname 2>/dev/null || hostname 2>/dev/null || echo '')}"

cd ~/dotfiles

# Skip if the current branch is not main
if [ "$(git rev-parse --abbrev-ref HEAD)" != "main" ]; then
  echo "Skipping update as current branch is not main"
  exit 0
fi

# Store current commit hash before fetching
CURRENT_COMMIT=$(git rev-parse HEAD)

# Fetch latest changes
git fetch origin main

# Get the latest remote commit
REMOTE_COMMIT=$(git rev-parse origin/main)

# Check if there are any changes
if [ "$CURRENT_COMMIT" = "$REMOTE_COMMIT" ]; then
  echo "No changes detected (current: ${CURRENT_COMMIT:0:8}). Skipping build and switch."
  exit 0
fi

echo "Changes detected: ${CURRENT_COMMIT:0:8} -> ${REMOTE_COMMIT:0:8}"

# Reset to latest
git reset --hard origin/main

# Run the install script
./install.sh
