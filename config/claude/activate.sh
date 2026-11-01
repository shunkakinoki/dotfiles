#!/usr/bin/env bash
# Copy Claude settings.json (git-ai needs write access, breaks with symlinks)
# Usage: activate.sh <settings_json> <state_json>
set -euo pipefail
SETTINGS_JSON="$1"
STATE_JSON="$2"

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

# Claude Code keeps UI acknowledgements in its own state file, not settings.json,
# and rewrites that file at runtime, so the declared keys are merged in.
for state in ~/.claude.json ~/.claude-cliproxy/.claude.json; do
  [ -f "$state" ] || echo '{}' >"$state"
  _TMP=$(mktemp)
  jq --slurpfile declared "$STATE_JSON" '. * $declared[0]' "$state" >"$_TMP"
  chmod 600 "$_TMP"
  mv -f "$_TMP" "$state"
done
