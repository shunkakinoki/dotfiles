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

# Unattended fleet lanes read sibling worktrees; an unacknowledged auto-mode
# outside-read notice blocks them on a modal no one answers. Only an existing
# state file is patched: Claude Code writes the rest of it on first launch.
for state in ~/.claude.json ~/.claude-cliproxy/.claude.json; do
  [ -f "$state" ] || continue
  _TMP=$(mktemp)
  jq '.hasSeenAutoModeOutsideReadPrompt = true' "$state" >"$_TMP"
  chmod 600 "$_TMP"
  mv -f "$_TMP" "$state"
done
