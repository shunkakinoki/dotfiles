#!/usr/bin/env bash
# Install managed Copilot hooks as a user hook file. Copilot rewrites
# config.json and settings.json itself, but never touches ~/.copilot/hooks.
# Usage: activate.sh <hooks_json>
set -euo pipefail

HOOKS_JSON="$1"

mkdir -p ~/.copilot/hooks
cp -f "$HOOKS_JSON" ~/.copilot/hooks/dotfiles.json
chmod 644 ~/.copilot/hooks/dotfiles.json
