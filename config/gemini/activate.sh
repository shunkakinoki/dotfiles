#!/usr/bin/env bash
# Copy the Nix-rendered Gemini settings.json on every activation.
# Usage: activate.sh <settings_json>
set -euo pipefail
SETTINGS_JSON="$1"

mkdir -p "$HOME/.gemini"
cp -f "$SETTINGS_JSON" "$HOME/.gemini/settings.json"
chmod 644 "$HOME/.gemini/settings.json"
