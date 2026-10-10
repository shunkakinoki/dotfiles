#!/usr/bin/env bash
# Copy Claude settings.json (git-ai needs write access, breaks with symlinks)
# Usage: activate.sh <settings_json>
set -euo pipefail
SETTINGS_JSON="$1"

# T3 Code's claude-cliproxy instance runs Claude Code with ~/.claude-cliproxy as
# its config dir, so it reads settings from there and never sees ~/.claude.
for dir in ~/.claude ~/.claude-cliproxy; do
  mkdir -p "$dir"
  _TMP=$(mktemp)
  jq --arg host "${HOSTNAME:-unknown}" '
    . * (.hostOverrides[$host] // {})
    | del(.hostOverrides)
  ' "$SETTINGS_JSON" >"$_TMP"
  mv "$_TMP" "$dir/settings.json"
  chmod 644 "$dir/settings.json"
done
