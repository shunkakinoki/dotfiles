#!/usr/bin/env bash
# shellcheck disable=SC2329,SC2016

Describe 'config/antigravity'
SCRIPT="$PWD/config/antigravity/activate.sh"
SETTINGS="$PWD/config/antigravity/settings.json"

setup() {
  TEMP_HOME=$(mktemp -d)
}

cleanup() {
  rm -rf "$TEMP_HOME"
}

Before 'setup'
After 'cleanup'

It 'creates writable default-backend Antigravity CLI settings'
When run bash -c 'HOME="$1" bash "$2" "$3" jq && jq -e '\''.model == "gemini-3.7-flash-high" and has("modelProvider") == false and (.permissions.allow | index("read_file(*)") != null)'\'' "$1/.gemini/antigravity-cli/settings.json" >/dev/null && find "$1/.gemini/antigravity-cli/settings.json" -prune -perm 600 -print -quit | grep -q .' _ "$TEMP_HOME" "$SCRIPT" "$SETTINGS"
The status should be success
The path "$TEMP_HOME/.gemini/antigravity-cli/settings.json" should be file
The path "$TEMP_HOME/.gemini/antigravity-cli/settings.json" should be writable
End

It 'preserves runtime preferences while removing the legacy explicit provider'
mkdir -p "$TEMP_HOME/.gemini/antigravity-cli"
cat >"$TEMP_HOME/.gemini/antigravity-cli/settings.json" <<'JSON'
{
  "modelProvider": "legacy",
  "model": "legacy-model",
  "showTips": false,
  "futureSetting": "preserved"
}
JSON
When run bash -c 'HOME="$1" bash "$2" "$3" jq && jq -e '\''.model == "gemini-3.7-flash-high" and has("modelProvider") == false and .showTips == false and .futureSetting == "preserved" and (.permissions.allow | index("read_file(*)") != null)'\'' "$1/.gemini/antigravity-cli/settings.json" >/dev/null && find "$1/.gemini/antigravity-cli/settings.json" -prune -perm 600 -print -quit | grep -q .' _ "$TEMP_HOME" "$SCRIPT" "$SETTINGS"
The status should be success
End

It 'fails closed without overwriting malformed runtime settings'
mkdir -p "$TEMP_HOME/.gemini/antigravity-cli"
printf '%s\n' '{broken' >"$TEMP_HOME/.gemini/antigravity-cli/settings.json"
When run bash -c 'HOME="$1" bash "$2" "$3" jq' _ "$TEMP_HOME" "$SCRIPT" "$SETTINGS"
The status should be failure
The error should include 'refusing to replace invalid Antigravity settings'
The contents of file "$TEMP_HOME/.gemini/antigravity-cli/settings.json" should equal '{broken'
End

It 'contains no remaining CCS integration outside this regression check'
When run bash -c "! git grep -niE '(^|[^[:alnum:]_])(ccs|claude code switch)([^[:alnum:]_]|$)' -- ':!spec/antigravity_config_spec.sh'"
The status should be success
End
End
