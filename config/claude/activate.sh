#!/usr/bin/env bash
# Copy Claude settings.json (git-ai needs write access, breaks with symlinks)
# Usage: activate.sh <settings_json>
set -euo pipefail
SETTINGS_JSON="$1"

mkdir -p ~/.claude
_TMP=$(mktemp)
jq --arg host "$(hostname)" '
  . * (.hostOverrides[$host] // {}) | del(.hostOverrides)
' "$SETTINGS_JSON" > "$_TMP"
mv "$_TMP" ~/.claude/settings.json
chmod 644 ~/.claude/settings.json
