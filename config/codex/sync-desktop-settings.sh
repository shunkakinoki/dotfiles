#!/usr/bin/env bash
# shellcheck disable=SC2016
# Keep managed Codex Desktop preferences in the app-owned global-state store.
set -euo pipefail

DESKTOP_SETTINGS_JSON="$1"
JQ_BIN="$2"
GLOBAL_STATE="$HOME/.codex/.codex-global-state.json"

mkdir -p "$HOME/.codex"

# Codex stores these preferences as top-level global-state keys. Older Desktop
# builds kept them inside electron-persisted-atom-state, so also require those
# legacy copies to be absent before treating the file as synchronized.
#
# Codex keeps this state in memory and periodically replaces the entire file.
# Avoid a write when the managed values already match so launchd's file watch
# settles after the synchronizer restores an app-owned rewrite.
if [[ -s $GLOBAL_STATE ]] && "$JQ_BIN" -e --slurpfile settings "$DESKTOP_SETTINGS_JSON" '
  $settings[0] as $managed
  | . as $state
  | ($managed | to_entries | all(. as $entry |
      $state[$entry.key] == $entry.value))
    and
    ((.["electron-persisted-atom-state"] // {}) as $legacy
      | ($managed | keys | all(. as $key | $legacy | has($key) | not)))
' "$GLOBAL_STATE" >/dev/null; then
  exit 0
fi

GLOBAL_STATE_TMP=$(mktemp "${GLOBAL_STATE}.tmp.XXXXXX")
trap 'rm -f "$GLOBAL_STATE_TMP"' EXIT

if [[ -s $GLOBAL_STATE ]]; then
  "$JQ_BIN" --slurpfile settings "$DESKTOP_SETTINGS_JSON" '
    $settings[0] as $managed
    | . + $managed
    | if (.["electron-persisted-atom-state"] | type) == "object" then
        .["electron-persisted-atom-state"] |=
          with_entries(select(.key as $key | $managed | has($key) | not))
      else
        .
      end
  ' "$GLOBAL_STATE" >"$GLOBAL_STATE_TMP"
else
  "$JQ_BIN" -n --slurpfile settings "$DESKTOP_SETTINGS_JSON" '
    $settings[0]
  ' >"$GLOBAL_STATE_TMP"
fi

chmod 600 "$GLOBAL_STATE_TMP"
mv -f "$GLOBAL_STATE_TMP" "$GLOBAL_STATE"
trap - EXIT
