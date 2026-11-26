#!/usr/bin/env bash
# Export local T3 Code model preferences (favorites, hidden/ordered models, and
# model selections) from ~/.t3/userdata/settings.json into
# config/t3code/server-settings.tpl.json, replacing known models.json IDs with
# their template placeholders, then re-rendering server-settings.json.
#
# Usage: t3-export-prefs.sh [settings_file] [template_file] [models_file]
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SETTINGS_FILE="${1:-${T3CODE_HOME:-$HOME/.t3}/userdata/settings.json}"
DEFAULT_TEMPLATE="$ROOT/config/t3code/server-settings.tpl.json"
TEMPLATE_FILE="${2:-$DEFAULT_TEMPLATE}"
MODELS_FILE="${3:-$ROOT/models.json}"

command -v jq >/dev/null 2>&1 || {
  echo "ERROR: jq is required" >&2
  exit 1
}

[ -f "$SETTINGS_FILE" ] || {
  echo "ERROR: T3 Code settings not found: $SETTINGS_FILE" >&2
  exit 1
}
[ -f "$TEMPLATE_FILE" ] || {
  echo "ERROR: T3 Code template not found: $TEMPLATE_FILE" >&2
  exit 1
}
[ -f "$MODELS_FILE" ] || {
  echo "ERROR: models.json not found: $MODELS_FILE" >&2
  exit 1
}

jq empty "$SETTINGS_FILE" >/dev/null 2>&1 || {
  echo "ERROR: T3 Code settings are not valid JSON: $SETTINGS_FILE" >&2
  exit 1
}

TEMP_FILE="$(mktemp "$(dirname "$TEMPLATE_FILE")/.t3-export-prefs.XXXXXX")"
cleanup() {
  rm -f "$TEMP_FILE"
}
trap cleanup EXIT

# shellcheck disable=SC2016
jq --slurpfile live "$SETTINGS_FILE" --slurpfile models "$MODELS_FILE" '
  def placeholder_for($key):
    "__" + ($key | ascii_upcase | gsub("-"; "_")) + "__";

  (
    ($models[0]
      | to_entries
      | sort_by([(.key | length), .key])
      | reduce .[] as $item ({}; if has($item.value) then . else . + {($item.value): placeholder_for($item.key)} end)
    ) + {"deepseek-v4.1-flash": "__DEEPSEEK_FLASH_UNVERSIONED__"}
  ) as $slug_map
  | def templatize_model:
      if type != "string" then .
      else
        split("/") as $parts
        | ($parts[-1]) as $slug
        | if ($slug_map | has($slug)) then
            ($parts[:-1] + [$slug_map[$slug]]) | join("/")
          else
            .
          end
      end;
  def templatize_selection:
    if type == "object" and has("model") then .model |= templatize_model else . end;
  def templatize_prefs:
    if type != "object" then {}
    else
      with_entries(
        .value |= (
          (if has("hiddenModels") and (.hiddenModels | type == "array") then .hiddenModels |= map(templatize_model) else . end)
          | (if has("modelOrder") and (.modelOrder | type == "array") then .modelOrder |= map(templatize_model) else . end)
        )
      )
    end;

  ($live[0]) as $src
  | .favorites = (
      ($src.favorites // [])
      | if type == "array" then map(if type == "object" and has("model") then .model |= templatize_model else . end) else [] end
    )
  | .providerModelPreferences = (($src.providerModelPreferences // {}) | templatize_prefs)
  | (if ($src.defaultModelSelection | type == "object") then .defaultModelSelection = ($src.defaultModelSelection | templatize_selection) else . end)
  | (if ($src.fallbackModelSelection | type == "object") then .fallbackModelSelection = ($src.fallbackModelSelection | templatize_selection) else . end)
  | (if ($src.textGenerationModelSelection | type == "object") then .textGenerationModelSelection = ($src.textGenerationModelSelection | templatize_selection) else . end)
  | (if ($src.reviewGuideModelSelection | type == "object") then .reviewGuideModelSelection = ($src.reviewGuideModelSelection | templatize_selection) else . end)
' "$TEMPLATE_FILE" >"$TEMP_FILE"

mv -f "$TEMP_FILE" "$TEMPLATE_FILE"
trap - EXIT

echo "Exported T3 Code model preferences from $SETTINGS_FILE -> $TEMPLATE_FILE"

if [ "$TEMPLATE_FILE" = "$DEFAULT_TEMPLATE" ] && [ -f "$ROOT/scripts/llm-update.sh" ]; then
  bash "$ROOT/scripts/llm-update.sh"
fi
