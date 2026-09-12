#!/usr/bin/env bash
# shellcheck disable=SC2329,SC2016

Describe 'config/devin'
SCRIPT="$PWD/config/devin/activate.sh"
MANAGED="$PWD/config/devin/hooks.v1.json"

setup() {
  TEMP_HOME=$(mktemp -d)
  export TEMP_HOME
}

cleanup() {
  rm -rf "$TEMP_HOME"
}

Before 'setup'
After 'cleanup'

It 'merges managed hooks and disables duplicate Claude imports'
mkdir -p "$TEMP_HOME/.config/devin"
cat >"$TEMP_HOME/.config/devin/config.json" <<'JSON'
{"version":0,"agent":{"model":"keep-me"},"read_config_from":{"cursor":true}}
JSON
When run bash -c 'HOME="$1" bash "$2" "$3" jq && jq -e '\'' .agent.model == "keep-me" and .read_config_from.cursor == true and .read_config_from.claude == false and (.hooks | has("PreToolUse")) '\'' "$1/.config/devin/config.json" >/dev/null' _ "$TEMP_HOME" "$SCRIPT" "$MANAGED"
The status should be success
End

It 'refuses to overwrite malformed Devin config'
mkdir -p "$TEMP_HOME/.config/devin"
printf '%s\n' '{broken' >"$TEMP_HOME/.config/devin/config.json"
When run bash -c 'HOME="$1" bash "$2" "$3" jq' _ "$TEMP_HOME" "$SCRIPT" "$MANAGED"
The status should be failure
The error should include 'refusing to replace invalid Devin config'
The contents of file "$TEMP_HOME/.config/devin/config.json" should equal '{broken'
End

It 'uses Devin lifecycle names and lowercase tool matchers'
When run jq -e 'has("read_config_from") and .read_config_from.claude == false and (.hooks.PreToolUse | any(.matcher == "^exec$")) and (.hooks.PostCompaction | length == 1)' "$MANAGED"
The status should be success
The output should eq 'true'
End
End
