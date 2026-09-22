#!/usr/bin/env bash
# shellcheck disable=SC2329,SC2016

Describe 'config/t3code/activate-settings.sh'
SETTINGS_SCRIPT="$PWD/config/t3code/activate-settings.sh"
CLIENT_SCRIPT="$PWD/config/t3code/activate-client-settings.sh"
MANAGED_SERVER="$PWD/config/t3code/server-settings.json"
MANAGED_CLIENT="$PWD/config/t3code/client-settings.json"
CODEX_HOME_CONFIG="$PWD/config/t3code/codex-home/config.toml"

setup() {
  TEMP_DIR=$(mktemp -d)
  STATE_DIR="$TEMP_DIR/userdata"
  mkdir -p "$STATE_DIR"
}

cleanup() {
  rm -rf "$TEMP_DIR"
}

run_settings() {
  bash "$SETTINGS_SCRIPT" "$MANAGED_SERVER" "$(command -v jq)" "$TEMP_DIR/.env" \
    "$STATE_DIR" "$CODEX_HOME_CONFIG"
}

run_client() {
  bash "$CLIENT_SCRIPT" "$MANAGED_CLIENT" "$(command -v jq)" "$STATE_DIR"
}

Before 'setup'
After 'cleanup'

It 'creates settings.json with the managed instances when absent'
cat >"$TEMP_DIR/.env" <<'ENV'
CLIPROXY_API_KEY=test_cliproxy_key
ENV
When run env HOME="$TEMP_DIR" bash -c "bash '$SETTINGS_SCRIPT' '$MANAGED_SERVER' \"\$(command -v jq)\" '$TEMP_DIR/.env' '$STATE_DIR' '$CODEX_HOME_CONFIG' && jq -e '.providerInstances[\"claude-cliproxy\"].driver == \"claudeAgent\" and .providerInstances[\"codex-cliproxy\"].driver == \"codex\"' '$STATE_DIR/settings.json' >/dev/null"
The status should be success
End

# T3 Code's ProviderInstanceConfig schema has no top-level homePath; the
# drivers read it from the opaque `config` blob. Keeping it at the top level
# makes T3 drop it on rewrite, so the instance falls back to the login-backed
# default home and reports the stale credential as logged out.
It 'carries the instance home path inside the config blob'
When run bash -c "jq -e '.providerInstances[\"claude-cliproxy\"].config.homePath == \"~/.claude-cliproxy\" and .providerInstances[\"codex-cliproxy\"].config.homePath == \"~/.codex-t3/cliproxy\"' '$MANAGED_SERVER' >/dev/null"
The status should be success
End

It 'declares no top-level home path on the managed instances'
When run bash -c "jq -e '[.providerInstances[] | select(has(\"homePath\"))] | length == 0' '$MANAGED_SERVER' >/dev/null"
The status should be success
End

It 'injects the CLIProxy key from the dotenv'
cat >"$TEMP_DIR/.env" <<'ENV'
CLIPROXY_API_KEY=test_cliproxy_key
ENV
When run env HOME="$TEMP_DIR" bash -c "bash '$SETTINGS_SCRIPT' '$MANAGED_SERVER' \"\$(command -v jq)\" '$TEMP_DIR/.env' '$STATE_DIR' '$CODEX_HOME_CONFIG' && jq -e '[.providerInstances[\"claude-cliproxy\"].environment[] | select(.name == \"ANTHROPIC_AUTH_TOKEN\") | .value == \"test_cliproxy_key\" and .sensitive == true] | all' '$STATE_DIR/settings.json' >/dev/null"
The status should be success
End

It 'renders the host-only base URL Claude Code expects'
cat >"$TEMP_DIR/.env" <<'ENV'
CLIPROXY_API_KEY=test_cliproxy_key
ENV
When run env HOME="$TEMP_DIR" bash -c "bash '$SETTINGS_SCRIPT' '$MANAGED_SERVER' \"\$(command -v jq)\" '$TEMP_DIR/.env' '$STATE_DIR' '$CODEX_HOME_CONFIG' && jq -e '[.providerInstances[\"claude-cliproxy\"].environment[] | select(.name == \"ANTHROPIC_BASE_URL\") | .value] | first == \"https://cliproxy.shunkakinoki.com\"' '$STATE_DIR/settings.json' >/dev/null"
The status should be success
End

It 'leaves the placeholder unresolved when the dotenv has no key'
: >"$TEMP_DIR/.env"
When run env -u CLIPROXY_API_KEY HOME="$TEMP_DIR" bash -c "bash '$SETTINGS_SCRIPT' '$MANAGED_SERVER' \"\$(command -v jq)\" '$TEMP_DIR/.env' '$STATE_DIR' '$CODEX_HOME_CONFIG' && jq -e '([.providerInstances[\"codex-cliproxy\"].environment[].value] | index(\"__CLIPROXY_API_KEY__\")) != null' '$STATE_DIR/settings.json' >/dev/null"
The status should be success
The stderr should include 'CLIPROXY_API_KEY not found'
End

It 'preserves app-owned settings and unrelated instances'
cat >"$TEMP_DIR/.env" <<'ENV'
CLIPROXY_API_KEY=test_cliproxy_key
ENV
cat >"$STATE_DIR/settings.json" <<'JSON'
{
  "pullRequestMergeMethod": "squash",
  "defaultModelSelection": {"instanceId": "opencode", "model": "shunkakinoki/deepseek-v4.1-flash"},
  "providerInstances": {"opencode": {"driver": "opencode", "config": {"binaryPath": "opencode"}}}
}
JSON
When run env HOME="$TEMP_DIR" bash -c "bash '$SETTINGS_SCRIPT' '$MANAGED_SERVER' \"\$(command -v jq)\" '$TEMP_DIR/.env' '$STATE_DIR' '$CODEX_HOME_CONFIG' && jq -e '.pullRequestMergeMethod == \"squash\" and .defaultModelSelection.instanceId == \"opencode\" and .providerInstances.opencode.config.binaryPath == \"opencode\" and (.providerInstances[\"codex-cliproxy\"] != null)' '$STATE_DIR/settings.json' >/dev/null"
The status should be success
End

It 'leaves a malformed settings.json untouched'
echo 'not json' >"$STATE_DIR/settings.json"
When run env HOME="$TEMP_DIR" bash -c "bash '$SETTINGS_SCRIPT' '$MANAGED_SERVER' \"\$(command -v jq)\" '$TEMP_DIR/.env' '$STATE_DIR' '$CODEX_HOME_CONFIG' && grep -q 'not json' '$STATE_DIR/settings.json'"
The status should be success
The stderr should include 'malformed, leaving them unchanged'
End

It 'provisions the Codex CLIProxy home from the managed config'
When run env HOME="$TEMP_DIR" CLIPROXY_API_KEY=test bash -c "mkdir -p '$TEMP_DIR/.codex-t3/cliproxy' && bash '$SETTINGS_SCRIPT' '$MANAGED_SERVER' \"\$(command -v jq)\" '$TEMP_DIR/.env' '$STATE_DIR' '$CODEX_HOME_CONFIG' && grep -q 'model_provider = \"cliproxyapi\"' '$TEMP_DIR/.codex-t3/cliproxy/config.toml'"
The status should be success
End

It 'seeds the Codex auth record so the instance is not reported as logged out'
When run env HOME="$TEMP_DIR" CLIPROXY_API_KEY=test bash -c "mkdir -p '$TEMP_DIR/.codex-t3/cliproxy' && bash '$SETTINGS_SCRIPT' '$MANAGED_SERVER' \"\$(command -v jq)\" '$TEMP_DIR/.env' '$STATE_DIR' '$CODEX_HOME_CONFIG' && jq -e '.OPENAI_API_KEY == \"test\"' '$TEMP_DIR/.codex-t3/cliproxy/auth.json' >/dev/null"
The status should be success
End

It 'writes no Codex auth record when the key is missing'
: >"$TEMP_DIR/.env"
When run env -u CLIPROXY_API_KEY HOME="$TEMP_DIR" bash -c "mkdir -p '$TEMP_DIR/.codex-t3/cliproxy' && bash '$SETTINGS_SCRIPT' '$MANAGED_SERVER' \"\$(command -v jq)\" '$TEMP_DIR/.env' '$STATE_DIR' '$CODEX_HOME_CONFIG' && [ ! -e '$TEMP_DIR/.codex-t3/cliproxy/auth.json' ]"
The status should be success
The stderr should include 'CLIPROXY_API_KEY not found'
End

It 'does not carry a committed credential in the managed template'
When run bash -c "! grep -qE 'sk-|sk_' '$MANAGED_SERVER'"
The status should be success
End

It 'creates client-settings.json with the managed favorites'
When run env HOME="$TEMP_DIR" bash -c "bash '$CLIENT_SCRIPT' '$MANAGED_CLIENT' \"\$(command -v jq)\" '$STATE_DIR' && jq -e '.favorites | map(.provider) | index(\"codex-cliproxy\") != null' '$STATE_DIR/client-settings.json' >/dev/null"
The status should be success
End

It 'replaces managed favorites without duplicating them'
cat >"$STATE_DIR/client-settings.json" <<'JSON'
{"favorites": [{"provider": "opencode", "model": "opencode/free"}, {"provider": "codex-cliproxy", "model": "gpt-5.6-sol"}]}
JSON
When run env HOME="$TEMP_DIR" bash -c "bash '$CLIENT_SCRIPT' '$MANAGED_CLIENT' \"\$(command -v jq)\" '$STATE_DIR' && jq -e '([.favorites[] | select(.provider == \"codex-cliproxy\")] | length == 1) and (.favorites | map(.provider) | index(\"opencode\") != null)' '$STATE_DIR/client-settings.json' >/dev/null"
The status should be success
End
End
