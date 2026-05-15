#!/usr/bin/env bash
# Merge managed Copilot config into the mutable user config.
# Usage: activate.sh <managed_config_json> [jq_bin]
set -euo pipefail

MANAGED_CONFIG_JSON="$1"
JQ_BIN="${2:-jq}"
COPILOT_DIR="${HOME}/.copilot"
CONFIG_JSON="${COPILOT_DIR}/config.json"

mkdir -p "$COPILOT_DIR"

if [ ! -f "$CONFIG_JSON" ]; then
  cp -f "$MANAGED_CONFIG_JSON" "$CONFIG_JSON"
  chmod 600 "$CONFIG_JSON"
  exit 0
fi

tmp=$(mktemp "${CONFIG_JSON}.tmp.XXXXXX")
trap 'rm -f "$tmp"' EXIT

# shellcheck disable=SC2016
"$JQ_BIN" -s '
  def hook_key:
    [
      (.type // ""),
      (.command // ""),
      (.bash // ""),
      (.powershell // "")
    ] | join("\\u0000");

  def dedupe_hooks:
    reduce .[] as $hook (
      { seen: {}, out: [] };
      ($hook | hook_key) as $key |
      if .seen[$key] then
        .
      else
        .seen[$key] = true | .out += [$hook]
      end
    ) | .out;

  .[0] as $current |
  .[1] as $managed |
  ($current * ($managed | del(.hooks))) as $base |
  $base + {
    hooks: (
      ($current.hooks // {}) as $existing |
      ($managed.hooks // {}) as $new |
      reduce (($existing + $new) | keys_unsorted[]) as $event (
        {};
        .[$event] = ((($existing[$event] // []) + ($new[$event] // [])) | dedupe_hooks)
      )
    )
  }
' "$CONFIG_JSON" "$MANAGED_CONFIG_JSON" >"$tmp"

cp -f "$tmp" "$CONFIG_JSON"
chmod 600 "$CONFIG_JSON"
