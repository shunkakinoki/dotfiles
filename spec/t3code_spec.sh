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
When run env -u CLIPROXY_API_KEY HOME="$TEMP_DIR" bash -c "bash '$SETTINGS_SCRIPT' '$MANAGED_SERVER' \"\$(command -v jq)\" '$TEMP_DIR/.env' '$STATE_DIR' '$CODEX_HOME_CONFIG' && jq -e '[.providerInstances[\"claude-cliproxy\"].environment[] | select(.name == \"ANTHROPIC_AUTH_TOKEN\") | .value == \"test_cliproxy_key\" and .sensitive == true] | all' '$STATE_DIR/settings.json' >/dev/null"
The status should be success
End

It 'renders the host-only base URL Claude Code expects'
cat >"$TEMP_DIR/.env" <<'ENV'
CLIPROXY_API_KEY=test_cliproxy_key
ENV
When run env HOME="$TEMP_DIR" bash -c "bash '$SETTINGS_SCRIPT' '$MANAGED_SERVER' \"\$(command -v jq)\" '$TEMP_DIR/.env' '$STATE_DIR' '$CODEX_HOME_CONFIG' && jq -e '[.providerInstances[\"claude-cliproxy\"].environment[] | select(.name == \"ANTHROPIC_BASE_URL\") | .value] | first == \"https://cliproxy.shunkakinoki.com\"' '$STATE_DIR/settings.json' >/dev/null"
The status should be success
End

# T3 Code copies a sensitive instance value into its own secret store, so a
# persisted placeholder is kept as if it were a credential and every CLIProxy
# request fails until someone clears the store by hand.
It 'never persists the placeholder when the dotenv has no key'
: >"$TEMP_DIR/.env"
When run env -u CLIPROXY_API_KEY HOME="$TEMP_DIR" bash -c "bash '$SETTINGS_SCRIPT' '$MANAGED_SERVER' \"\$(command -v jq)\" '$TEMP_DIR/.env' '$STATE_DIR' '$CODEX_HOME_CONFIG' && jq -e '[.. | strings | select(. == \"__CLIPROXY_API_KEY__\")] | length == 0' '$STATE_DIR/settings.json' >/dev/null"
The status should be success
The stderr should include 'CLIPROXY_API_KEY not found'
End

# The dotenv is hydrated out of band, so an activation that races it must not
# blank a credential T3 Code is already using.
It 'keeps the credential T3 already holds when the dotenv has no key'
: >"$TEMP_DIR/.env"
cat >"$STATE_DIR/settings.json" <<'JSON'
{
  "providerInstances": {
    "claude-cliproxy": {
      "driver": "claudeAgent",
      "environment": [{"name": "ANTHROPIC_AUTH_TOKEN", "value": "existing_key", "sensitive": true}]
    }
  }
}
JSON
When run env -u CLIPROXY_API_KEY HOME="$TEMP_DIR" bash -c "bash '$SETTINGS_SCRIPT' '$MANAGED_SERVER' \"\$(command -v jq)\" '$TEMP_DIR/.env' '$STATE_DIR' '$CODEX_HOME_CONFIG' && jq -e '([.providerInstances[\"claude-cliproxy\"].environment[] | select(.name == \"ANTHROPIC_AUTH_TOKEN\") | .value] | first == \"existing_key\") and (.providerInstances[\"codex-cliproxy\"].environment[0].value == \"existing_key\")' '$STATE_DIR/settings.json' >/dev/null"
The status should be success
End

It 'purges a secret-store entry that holds the placeholder'
cat >"$TEMP_DIR/.env" <<'ENV'
CLIPROXY_API_KEY=test_cliproxy_key
ENV
mkdir -p "$STATE_DIR/secrets"
printf '%s' '__CLIPROXY_API_KEY__' >"$STATE_DIR/secrets/provider-env-poisoned.bin"
printf '%s' 'real_key' >"$STATE_DIR/secrets/provider-env-healthy.bin"
When run env HOME="$TEMP_DIR" bash -c "bash '$SETTINGS_SCRIPT' '$MANAGED_SERVER' \"\$(command -v jq)\" '$TEMP_DIR/.env' '$STATE_DIR' '$CODEX_HOME_CONFIG' && [ ! -e '$STATE_DIR/secrets/provider-env-poisoned.bin' ] && [ -e '$STATE_DIR/secrets/provider-env-healthy.bin' ]"
The status should be success
End

# T3 Code serves the provider from its secret store, not from the settings
# value, so a render that only writes settings.json leaves the instance running
# on whatever the store already held.
It 'writes the credential into the T3 secret store'
cat >"$TEMP_DIR/.env" <<'ENV'
CLIPROXY_API_KEY=test_cliproxy_key
ENV
CLAUDE_SECRET="$STATE_DIR/secrets/provider-env-Y2xhdWRlLWNsaXByb3h5-QU5USFJPUElDX0FVVEhfVE9LRU4.bin"
CODEX_SECRET="$STATE_DIR/secrets/provider-env-Y29kZXgtY2xpcHJveHk-Q0xJUFJPWFlfQVBJX0tFWQ.bin"
When run env -u CLIPROXY_API_KEY HOME="$TEMP_DIR" bash -c "bash '$SETTINGS_SCRIPT' '$MANAGED_SERVER' \"\$(command -v jq)\" '$TEMP_DIR/.env' '$STATE_DIR' '$CODEX_HOME_CONFIG' && [ \"\$(cat '$CLAUDE_SECRET')\" = test_cliproxy_key ] && [ \"\$(cat '$CODEX_SECRET')\" = test_cliproxy_key ] && [ \"\$(stat -c %a '$CLAUDE_SECRET')\" = 600 ]"
The status should be success
End

# T3 strips the value from the settings once it owns the secret, so the store is
# the only remaining copy on a host whose dotenv has since gone missing.
# T3 Code watches its settings and reloads provider state when they change, so
# an activation that renders the same content must touch nothing.
It 'rewrites nothing when the render is unchanged'
cat >"$TEMP_DIR/.env" <<'ENV'
CLIPROXY_API_KEY=test_cliproxy_key
ENV
RENDER="bash '$SETTINGS_SCRIPT' '$MANAGED_SERVER' \"\$(command -v jq)\" '$TEMP_DIR/.env' '$STATE_DIR' '$CODEX_HOME_CONFIG'"
TOUCHED="'$STATE_DIR/settings.json' '$TEMP_DIR/.codex-t3/cliproxy/auth.json' '$TEMP_DIR/.codex-t3/cliproxy/config.toml' '$STATE_DIR/secrets/provider-env-Y2xhdWRlLWNsaXByb3h5-QU5USFJPUElDX0FVVEhfVE9LRU4.bin'"
When run env -u CLIPROXY_API_KEY HOME="$TEMP_DIR" bash -c "$RENDER && before=\$(stat -c %y $TOUCHED) && $RENDER && [ \"\$before\" = \"\$(stat -c %y $TOUCHED)\" ]"
The status should be success
End

It 'leaves no temporary render behind'
cat >"$TEMP_DIR/.env" <<'ENV'
CLIPROXY_API_KEY=test_cliproxy_key
ENV
When run env -u CLIPROXY_API_KEY HOME="$TEMP_DIR" bash -c "bash '$SETTINGS_SCRIPT' '$MANAGED_SERVER' \"\$(command -v jq)\" '$TEMP_DIR/.env' '$STATE_DIR' '$CODEX_HOME_CONFIG' && bash '$SETTINGS_SCRIPT' '$MANAGED_SERVER' \"\$(command -v jq)\" '$TEMP_DIR/.env' '$STATE_DIR' '$CODEX_HOME_CONFIG' && [ \"\$(find '$STATE_DIR' -name 'settings.json.*' | wc -l)\" -eq 0 ]"
The status should be success
End

It 'recovers the credential from the secret store'
: >"$TEMP_DIR/.env"
mkdir -p "$STATE_DIR/secrets"
printf '%s' 'stored_key' >"$STATE_DIR/secrets/provider-env-Y2xhdWRlLWNsaXByb3h5-QU5USFJPUElDX0FVVEhfVE9LRU4.bin"
When run env -u CLIPROXY_API_KEY HOME="$TEMP_DIR" bash -c "bash '$SETTINGS_SCRIPT' '$MANAGED_SERVER' \"\$(command -v jq)\" '$TEMP_DIR/.env' '$STATE_DIR' '$CODEX_HOME_CONFIG' && jq -e '([.providerInstances[\"claude-cliproxy\"].environment[] | select(.name == \"ANTHROPIC_AUTH_TOKEN\") | .value] | first == \"stored_key\")' '$STATE_DIR/settings.json' >/dev/null"
The status should be success
End

It 'restarts t3code when the credential first becomes resolvable'
cat >"$TEMP_DIR/.env" <<'ENV'
CLIPROXY_API_KEY=test_cliproxy_key
ENV
cat >"$TEMP_DIR/systemctl" <<SYSTEMCTL
#!/usr/bin/env bash
printf '%s\n' "\$*" >>"$TEMP_DIR/systemctl.log"
SYSTEMCTL
chmod +x "$TEMP_DIR/systemctl"
When run env HOME="$TEMP_DIR" bash -c "bash '$SETTINGS_SCRIPT' '$MANAGED_SERVER' \"\$(command -v jq)\" '$TEMP_DIR/.env' '$STATE_DIR' '$CODEX_HOME_CONFIG' '$TEMP_DIR/systemctl' && grep -q 'restart t3code.service' '$TEMP_DIR/systemctl.log'"
The status should be success
End

It 'leaves t3code alone when the credential is unchanged'
cat >"$TEMP_DIR/.env" <<'ENV'
CLIPROXY_API_KEY=test_cliproxy_key
ENV
cat >"$TEMP_DIR/systemctl" <<SYSTEMCTL
#!/usr/bin/env bash
printf '%s\n' "\$*" >>"$TEMP_DIR/systemctl.log"
SYSTEMCTL
chmod +x "$TEMP_DIR/systemctl"
When run env HOME="$TEMP_DIR" bash -c "bash '$SETTINGS_SCRIPT' '$MANAGED_SERVER' \"\$(command -v jq)\" '$TEMP_DIR/.env' '$STATE_DIR' '$CODEX_HOME_CONFIG' '$TEMP_DIR/systemctl' && bash '$SETTINGS_SCRIPT' '$MANAGED_SERVER' \"\$(command -v jq)\" '$TEMP_DIR/.env' '$STATE_DIR' '$CODEX_HOME_CONFIG' '$TEMP_DIR/systemctl' && [ \"\$(wc -l <'$TEMP_DIR/systemctl.log')\" -eq 1 ]"
The status should be success
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

It 'merges the managed load-balancing toggle over an existing value'
cat >"$STATE_DIR/client-settings.json" <<'JSON'
{"loadBalancingEnabled": false, "loadBalancingWeights": {"env-a": 0}}
JSON
When run env HOME="$TEMP_DIR" bash -c "bash '$CLIENT_SCRIPT' '$MANAGED_CLIENT' \"\$(command -v jq)\" '$STATE_DIR' && jq -e '.loadBalancingEnabled == true and .loadBalancingWeights[\"env-a\"] == 0' '$STATE_DIR/client-settings.json' >/dev/null"
The status should be success
End

It 'overrides a managed weight, keeps a device-local one, and adds the rest'
cat >"$STATE_DIR/client-settings.json" <<'JSON'
{"loadBalancingWeights": {"env-a": 0, "df67cbf5-ef55-405a-91ca-d5b506c339bc": 50}}
JSON
When run env HOME="$TEMP_DIR" bash -c "bash '$CLIENT_SCRIPT' '$MANAGED_CLIENT' \"\$(command -v jq)\" '$STATE_DIR' && jq -e '.loadBalancingWeights[\"df67cbf5-ef55-405a-91ca-d5b506c339bc\"] == 25 and .loadBalancingWeights[\"env-a\"] == 0 and ([.loadBalancingWeights[] | select(. == 100)] | length) == 6' '$STATE_DIR/client-settings.json' >/dev/null"
The status should be success
End

It 'leaves the load-balancing toggle alone when the template omits it'
cat >"$STATE_DIR/client-settings.json" <<'JSON'
{"loadBalancingEnabled": false}
JSON
When run env HOME="$TEMP_DIR" bash -c "jq 'del(.loadBalancingEnabled)' '$MANAGED_CLIENT' >'$TEMP_DIR/managed-without-toggle.json' && bash '$CLIENT_SCRIPT' '$TEMP_DIR/managed-without-toggle.json' \"\$(command -v jq)\" '$STATE_DIR' && jq -e '.loadBalancingEnabled == false' '$STATE_DIR/client-settings.json' >/dev/null"
The status should be success
End
End
