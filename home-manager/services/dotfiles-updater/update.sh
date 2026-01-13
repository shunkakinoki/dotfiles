#!/usr/bin/env bash

set -euo pipefail

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

# Check if clawdbot-related files changed (flake.lock or clawdbot module)
CLAWDBOT_CHANGED=false
CHANGED_FILES=$(git diff --name-only "$CURRENT_COMMIT" "$REMOTE_COMMIT")
if echo "$CHANGED_FILES" | grep -qE "(flake\.lock|clawdbot)"; then
  CLAWDBOT_CHANGED=true
  echo "Clawdbot-related files changed, will restart after switch"
fi

# Reset to latest
git reset --hard origin/main

# Run the install script
./install.sh

# Restart clawdbot only if clawdbot-related files changed
if [ "$CLAWDBOT_CHANGED" = "true" ]; then
  echo "Restarting clawdbot due to config/flake changes..."
  systemctl --user restart clawdbot-gateway.service || true
fi
