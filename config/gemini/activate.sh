#!/usr/bin/env bash
# Copy the Nix-rendered Gemini settings.json on every activation.
# Usage: activate.sh <settings_json> <antigravity_hooks_json>
set -euo pipefail
SETTINGS_JSON="$1"
ANTIGRAVITY_HOOKS_JSON="$2"

mkdir -p "$HOME/.gemini/config"
cp -f "$SETTINGS_JSON" "$HOME/.gemini/settings.json"
chmod 644 "$HOME/.gemini/settings.json"
cp -f "$ANTIGRAVITY_HOOKS_JSON" "$HOME/.gemini/config/hooks.json"
chmod 644 "$HOME/.gemini/config/hooks.json"
