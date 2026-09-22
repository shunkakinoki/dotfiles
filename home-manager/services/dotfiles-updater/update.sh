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

# The marker records the last commit whose install succeeded. HEAD cannot serve
# as that record, not even as a fallback: the reset below moves HEAD before
# install.sh runs, so a failed install would be skipped as "no changes" forever.
MARKER_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles-updater"
INSTALLED_MARKER="$MARKER_DIR/installed-commit"
CURRENT_COMMIT=$(git rev-parse HEAD)
INSTALLED_COMMIT=$(cat "$INSTALLED_MARKER" 2>/dev/null || true)

# Activation reads secrets from the untracked dotenv, which is placed out of
# band and so can land after the switch that needed it. Commit equality alone
# would then skip activation forever and strand the host on whatever it rendered
# without the file. The marker holds a digest, never the contents.
DOTENV_FILE=.env
DOTENV_MARKER="$MARKER_DIR/installed-dotenv"
INSTALLED_DOTENV=$(cat "$DOTENV_MARKER" 2>/dev/null || true)
if [ -f "$DOTENV_FILE" ]; then
  DOTENV_FINGERPRINT=$(sha256sum "$DOTENV_FILE" | cut -d' ' -f1)
else
  DOTENV_FINGERPRINT=absent
fi

# Fetch latest changes
git fetch origin main

# Get the latest remote commit
REMOTE_COMMIT=$(git rev-parse origin/main)

# Check if there are any changes
if [ "$INSTALLED_COMMIT" = "$REMOTE_COMMIT" ] && [ "$INSTALLED_DOTENV" = "$DOTENV_FINGERPRINT" ]; then
  echo "No changes detected (current: ${CURRENT_COMMIT:0:8}). Skipping build and switch."
  exit 0
fi

if [ "$INSTALLED_COMMIT" != "$REMOTE_COMMIT" ]; then
  echo "Changes detected: ${CURRENT_COMMIT:0:8} -> ${REMOTE_COMMIT:0:8} (installed: ${INSTALLED_COMMIT:0:8})"
else
  echo "Dotenv changed since the last install; re-running activation."
fi

# Reset to latest
git reset --hard origin/main

# Run the install script
./install.sh

mkdir -p "$MARKER_DIR"
printf '%s\n' "$REMOTE_COMMIT" >"$INSTALLED_MARKER"
printf '%s\n' "$DOTENV_FINGERPRINT" >"$DOTENV_MARKER"
