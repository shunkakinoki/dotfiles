#!/usr/bin/env bash
# Copy Claude settings.json (git-ai needs write access, breaks with symlinks)
# Usage: activate.sh <settings_json>
set -euo pipefail
SETTINGS_JSON="$1"

mkdir -p ~/.claude
cp -f "$SETTINGS_JSON" ~/.claude/settings.json
chmod 644 ~/.claude/settings.json
