#!/usr/bin/env bash
# shellcheck disable=SC2016
# Merge managed Devin config into the writable user config.
# Usage: activate.sh <config_json> [jq]
set -euo pipefail

MANAGED_CONFIG="$1"
JQ="${2:-jq}"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/devin"
CONFIG_FILE="$CONFIG_DIR/config.json"

"$JQ" -e 'type == "object"' "$MANAGED_CONFIG" >/dev/null
mkdir -p "$CONFIG_DIR"

if [[ -f $CONFIG_FILE ]] && ! "$JQ" -e 'type == "object"' "$CONFIG_FILE" >/dev/null; then
  echo "ERROR: refusing to replace invalid Devin config: $CONFIG_FILE" >&2
  exit 1
fi

tmp="$(mktemp "$CONFIG_DIR/config.json.XXXXXX")"
trap 'rm -f "$tmp"' EXIT

if [[ -f $CONFIG_FILE ]]; then
  "$JQ" -s '
    .[0] as $current
    | .[1] as $managed
    | ($current * $managed)
    | if ($managed.read_config_from? // null) != null then
        .read_config_from = (($current.read_config_from // {}) * $managed.read_config_from)
      else . end
  ' "$CONFIG_FILE" "$MANAGED_CONFIG" >"$tmp"
else
  "$JQ" '.' "$MANAGED_CONFIG" >"$tmp"
fi

chmod 600 "$tmp"
mv -f "$tmp" "$CONFIG_FILE"
trap - EXIT
