#!/usr/bin/env bash
# Copy Cursor hooks.json (git-ai needs write access, breaks with symlinks)
# Usage: activate.sh <hooks_json>
set -euo pipefail
HOOKS_JSON="$1"

mkdir -p ~/.cursor
cp -f "$HOOKS_JSON" ~/.cursor/hooks.json
chmod 644 ~/.cursor/hooks.json
