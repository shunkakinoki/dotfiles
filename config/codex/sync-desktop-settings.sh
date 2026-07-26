#!/usr/bin/env bash
# shellcheck disable=SC2016
# Keep managed Codex Desktop preferences in the app-owned global-state store.
set -euo pipefail

DESKTOP_SETTINGS_JSON="$1"
JQ_BIN="$2"
GLOBAL_STATE="$HOME/.codex/.codex-global-state.json"

mkdir -p "$HOME/.codex"

# Codex Desktop stores these preferences in its persisted atom-state object.
# Top-level copies are ignored by the settings UI, so require those stale copies
# to be absent before treating the file as synchronized.
#
# Codex keeps this state in memory and periodically replaces the entire file.
# Avoid a write when the managed values already match so launchd's file watch
# settles after the synchronizer restores an app-owned rewrite.
if [[ -s $GLOBAL_STATE ]] && "$JQ_BIN" -e --slurpfile settings "$DESKTOP_SETTINGS_JSON" '
  $settings[0] as $managed
  | . as $state
  | (($state["electron-persisted-atom-state"] // {}) as $atoms
      | ($managed | to_entries | all(. as $entry |
          $atoms[$entry.key] == $entry.value)))
    and
    ($managed | keys | all(. as $key | $state | has($key) | not))
' "$GLOBAL_STATE" >/dev/null; then
  exit 0
fi

GLOBAL_STATE_TMP=$(mktemp "${GLOBAL_STATE}.tmp.XXXXXX")
trap 'rm -f "$GLOBAL_STATE_TMP"' EXIT

if [[ -s $GLOBAL_STATE ]]; then
  "$JQ_BIN" --slurpfile settings "$DESKTOP_SETTINGS_JSON" '
    $settings[0] as $managed
    | (if (.["electron-persisted-atom-state"] | type) == "object"
        then .["electron-persisted-atom-state"]
        else {}
      end) as $atoms
    | with_entries(select(.key as $key | $managed | has($key) | not))
    | .["electron-persisted-atom-state"] = ($atoms + $managed)
  ' "$GLOBAL_STATE" >"$GLOBAL_STATE_TMP"
else
  "$JQ_BIN" -n --slurpfile settings "$DESKTOP_SETTINGS_JSON" '
    {"electron-persisted-atom-state": $settings[0]}
  ' >"$GLOBAL_STATE_TMP"
fi

chmod 600 "$GLOBAL_STATE_TMP"
mv -f "$GLOBAL_STATE_TMP" "$GLOBAL_STATE"
trap - EXIT
