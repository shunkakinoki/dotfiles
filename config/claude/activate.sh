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

# Traces indexes only ~/.claude/projects, so T3 Code sessions under
# ~/.claude-cliproxy are never uploaded or linked to commits unless both config
# dirs share one projects dir. Session files are UUID-named, so merging cannot
# overwrite; mv -n keeps any file that does collide in the pending dir.
shared=~/.claude/projects
cliproxy=~/.claude-cliproxy/projects
pending="$cliproxy.merging"
mkdir -p "$shared"

merge_into_shared() {
  (
    cd "$1"
    find . ! -type d -print0 | while IFS= read -r -d '' file; do
      mkdir -p "$shared/$(dirname "$file")"
      mv -n "$file" "$shared/$file"
    done
  )
  find "$1" -depth -type d -empty -delete
  if [ -e "$1" ]; then
    echo "claude activate: files left in $1 already exist in $shared" >&2
  fi
}

if [ -d "$pending" ]; then
  merge_into_shared "$pending"
fi
if [ -d "$cliproxy" ] && [ ! -L "$cliproxy" ] && [ ! -e "$pending" ]; then
  mv "$cliproxy" "$pending"
  ln -s "$shared" "$cliproxy"
  merge_into_shared "$pending"
fi
if [ ! -e "$cliproxy" ] && [ ! -L "$cliproxy" ]; then
  ln -s "$shared" "$cliproxy"
fi
