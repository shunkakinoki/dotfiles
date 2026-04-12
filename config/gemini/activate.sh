#!/usr/bin/env bash
# Copy Gemini settings.json if it doesn't already exist
# Usage: activate.sh <settings_json>
set -euo pipefail
SETTINGS_JSON="$1"

mkdir -p "$HOME/.gemini"
if [ ! -f "$HOME/.gemini/settings.json" ]; then
  cp "$SETTINGS_JSON" "$HOME/.gemini/settings.json"
  chmod 644 "$HOME/.gemini/settings.json"
fi
