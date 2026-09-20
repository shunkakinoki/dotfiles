#!/usr/bin/env bash
# Merge managed T3 Code client preferences (favorites, model visibility) into
# the device-local client settings file. T3 owns this file and rewrites it as
# the app evolves, so merge only the managed keys.
#
# Usage: activate-client-settings.sh <managed_client_json> <jq_bin> <state_dir>
set -euo pipefail

MANAGED_CLIENT="$1"
JQ_BIN="$2"
STATE_DIR="$3"

SETTINGS="${STATE_DIR}/client-settings.json"
TEMP_SETTINGS=""

cleanup() {
  if [ -n "$TEMP_SETTINGS" ]; then
    rm -f "$TEMP_SETTINGS"
  fi
}
trap cleanup EXIT

mkdir -p "$STATE_DIR"
TEMP_SETTINGS="$(mktemp "${STATE_DIR}/client-settings.json.XXXXXX")"

if [ -f "$SETTINGS" ] && ! "$JQ_BIN" empty "$SETTINGS" >/dev/null 2>&1; then
  echo "Warning: T3 Code client settings are malformed, leaving them unchanged: $SETTINGS" >&2
  exit 0
fi

if [ -f "$SETTINGS" ]; then
  # shellcheck disable=SC2016
  "$JQ_BIN" --slurpfile managed "$MANAGED_CLIENT" '
    ($managed[0]) as $managed_settings
    | .favorites = (
        ((.favorites // [])
         | map(select(
             .provider as $provider
             | ($managed_settings.favorites // [] | map(.provider) | index($provider) | not)
           )))
        + ($managed_settings.favorites // [])
      )
  ' "$SETTINGS" >"$TEMP_SETTINGS"
else
  # shellcheck disable=SC2016
  "$JQ_BIN" --slurpfile managed "$MANAGED_CLIENT" '$managed[0]' -n >"$TEMP_SETTINGS"
fi

mv -f "$TEMP_SETTINGS" "$SETTINGS"
chmod 600 "$SETTINGS"
trap - EXIT
