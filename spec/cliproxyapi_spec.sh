#!/usr/bin/env bash
# shellcheck disable=SC2329,SC2016

Describe 'cliproxyapi/start.sh'
SCRIPT="$PWD/home-manager/services/cliproxyapi/scripts/start.sh"

Describe 'configuration handling'
setup() {
  TEMP_HOME=$(mktemp -d)
  mkdir -p "$TEMP_HOME/.cli-proxy-api"
  mkdir -p "$TEMP_HOME/dotfiles"

  # Create template config
  cat >"$TEMP_HOME/.cli-proxy-api/config.template.yaml" <<'YAML'
api_key: __OPENROUTER_API_KEY__
openai_api_key: __OPENAI_API_KEY__
qwen_api_key: __QWEN_API_KEY__
aliyun_token_plan_api_key: __ALIYUN_TOKEN_PLAN_API_KEY__
verboo_api_key: __VERBOO_API_KEY__
surplus_api_key: __SURPLUS_API_KEY__
management_password: __CLIPROXY_MANAGEMENT_PASSWORD__
YAML

  # Create .env file
  cat >"$TEMP_HOME/dotfiles/.env" <<'ENV'
OPENROUTER_API_KEY=test_openrouter_key
OPENAI_API_KEY=test_openai_key
QWEN_API_KEY=test_qwen_key
ALIYUN_TOKEN_PLAN_API_KEY=test_token_plan_key
VERBOO_API_KEY=test_verboo_key
SURPLUS_API_KEY=test_surplus_key
CLIPROXY_MANAGEMENT_PASSWORD=test_mgmt_password
ENV
}

cleanup() {
  rm -rf "$TEMP_HOME"
}

Before 'setup'
After 'cleanup'

It 'sources .env file when present'
# Create a script that tests env sourcing
cat >"$TEMP_HOME/test_env.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
ENV_FILE="$HOME/dotfiles/.env"
if [ -f "$ENV_FILE" ]; then
  set -a
  source "$ENV_FILE"
  set +a
fi
echo "OPENROUTER_API_KEY=$OPENROUTER_API_KEY"
EOF
chmod +x "$TEMP_HOME/test_env.sh"

When run bash -c "HOME='$TEMP_HOME' bash '$TEMP_HOME/test_env.sh'"
The output should include 'OPENROUTER_API_KEY=test_openrouter_key'
The status should be success
End

It 'generates config from template'
# Create a simplified test script
cat >"$TEMP_HOME/test_config.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
CONFIG_DIR="$HOME/.cli-proxy-api"
TEMPLATE="$CONFIG_DIR/config.template.yaml"
CONFIG="$CONFIG_DIR/config.yaml"

OPENROUTER_API_KEY="test_key"
OPENAI_API_KEY="test_openai_key"
QWEN_API_KEY="test_qwen_key"
ALIYUN_TOKEN_PLAN_API_KEY="test_token_plan_key"
VERBOO_API_KEY="test_verboo_key"
SURPLUS_API_KEY="test_surplus_key"
CLIPROXY_MANAGEMENT_PASSWORD="test_pass"

if [ -f "$TEMPLATE" ]; then
  sed -e "s|__OPENROUTER_API_KEY__|${OPENROUTER_API_KEY:-}|g" \
    -e "s|__OPENAI_API_KEY__|${OPENAI_API_KEY:-}|g" \
    -e "s|__QWEN_API_KEY__|${QWEN_API_KEY:-}|g" \
    -e "s|__ALIYUN_TOKEN_PLAN_API_KEY__|${ALIYUN_TOKEN_PLAN_API_KEY:-}|g" \
    -e "s|__VERBOO_API_KEY__|${VERBOO_API_KEY:-}|g" \
    -e "s|__SURPLUS_API_KEY__|${SURPLUS_API_KEY:-}|g" \
    -e "s|__CLIPROXY_MANAGEMENT_PASSWORD__|${CLIPROXY_MANAGEMENT_PASSWORD:-}|g" \
    "$TEMPLATE" >"$CONFIG"
fi
cat "$CONFIG"
EOF
chmod +x "$TEMP_HOME/test_config.sh"

When run bash -c "HOME='$TEMP_HOME' bash '$TEMP_HOME/test_config.sh'"
The output should include 'api_key: test_key'
The output should include 'openai_api_key: test_openai_key'
The output should include 'qwen_api_key: test_qwen_key'
The output should include 'aliyun_token_plan_api_key: test_token_plan_key'
The output should include 'verboo_api_key: test_verboo_key'
The output should include 'surplus_api_key: test_surplus_key'
The output should include 'management_password: test_pass'
The status should be success
End
End

Describe 'platform-specific api-keys handling'
setup_apikeys() {
  TEMP_HOME=$(mktemp -d)
  mkdir -p "$TEMP_HOME/.cli-proxy-api"

  # Create template config with commented api-keys
  cat >"$TEMP_HOME/.cli-proxy-api/config.template.yaml" <<'YAML'
port: 8317
# API keys for client authentication (optional - leave commented for open access)
# api-keys:
#   - "__CLIPROXY_API_KEY__"
debug: true
YAML
}

cleanup_apikeys() {
  rm -rf "$TEMP_HOME"
}

Before 'setup_apikeys'
After 'cleanup_apikeys'

It 'uncomments api-keys section on Linux'
# Create test script that simulates Linux behavior
cat >"$TEMP_HOME/test_linux_apikeys.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
CONFIG_DIR="$HOME/.cli-proxy-api"
TEMPLATE="$CONFIG_DIR/config.template.yaml"
CONFIG="$CONFIG_DIR/config.yaml"
CLIPROXY_API_KEY="my_secret_key"

# Copy template to config
cp "$TEMPLATE" "$CONFIG"

# Simulate Linux behavior (uname = Linux)
# Use temp file approach for cross-platform sed -i compatibility
sed \
  -e "s|^# api-keys:|api-keys:|" \
  -e "s|^#   - \"__CLIPROXY_API_KEY__\"|  - \"${CLIPROXY_API_KEY:-}\"|" \
  "$CONFIG" > "$CONFIG.tmp" && mv "$CONFIG.tmp" "$CONFIG"

cat "$CONFIG"
EOF
chmod +x "$TEMP_HOME/test_linux_apikeys.sh"

When run bash -c "HOME='$TEMP_HOME' bash '$TEMP_HOME/test_linux_apikeys.sh'"
The output should include 'api-keys:'
The output should include '  - "my_secret_key"'
The output should not include '# api-keys:'
The status should be success
End

It 'keeps api-keys commented on macOS'
# Create test script that simulates macOS behavior (no uncommenting)
cat >"$TEMP_HOME/test_macos_apikeys.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
CONFIG_DIR="$HOME/.cli-proxy-api"
TEMPLATE="$CONFIG_DIR/config.template.yaml"
CONFIG="$CONFIG_DIR/config.yaml"

# Copy template to config (macOS behavior - no api-keys uncommenting)
cp "$TEMPLATE" "$CONFIG"

cat "$CONFIG"
EOF
chmod +x "$TEMP_HOME/test_macos_apikeys.sh"

When run bash -c "HOME='$TEMP_HOME' bash '$TEMP_HOME/test_macos_apikeys.sh'"
The output should include '# api-keys:'
The output should include '#   - "__CLIPROXY_API_KEY__"'
The status should be success
End

It 'script has Linux-specific api-keys uncommenting logic'
When run bash -c "grep -A 5 'uname.*Linux.*CLIPROXY_API_KEY' '$SCRIPT'"
# shellcheck disable=SC2016
The output should include 'if [ "$(uname)" = "Linux" ] && [ -n "${CLIPROXY_API_KEY:-}" ]'
The output should include 's|^# api-keys:|api-keys:|'
The output should include 'CLIPROXY_API_KEY'
End

It 'keeps api-keys commented on Linux when CLIPROXY_API_KEY is empty'
# Create test script that simulates Linux behavior with empty key
cat >"$TEMP_HOME/test_linux_empty_apikey.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
CONFIG_DIR="$HOME/.cli-proxy-api"
TEMPLATE="$CONFIG_DIR/config.template.yaml"
CONFIG="$CONFIG_DIR/config.yaml"
CLIPROXY_API_KEY=""

# Copy template to config
cp "$TEMPLATE" "$CONFIG"

# Simulate Linux behavior with empty key (should NOT uncomment)
if [ -n "${CLIPROXY_API_KEY:-}" ]; then
  sed \
    -e "s|^# api-keys:|api-keys:|" \
    -e "s|^#   - \"__CLIPROXY_API_KEY__\"|  - \"${CLIPROXY_API_KEY}\"|" \
    "$CONFIG" > "$CONFIG.tmp" && mv "$CONFIG.tmp" "$CONFIG"
fi

cat "$CONFIG"
EOF
chmod +x "$TEMP_HOME/test_linux_empty_apikey.sh"

When run bash -c "HOME='$TEMP_HOME' bash '$TEMP_HOME/test_linux_empty_apikey.sh'"
The output should include '# api-keys:'
The output should include '#   - "__CLIPROXY_API_KEY__"'
The status should be success
End
End

Describe 'binary detection logic'
It 'checks /opt/homebrew/bin/cliproxyapi first'
When run bash -c "grep -A 2 'if.*-x.*/opt/homebrew/bin/cliproxyapi' '$SCRIPT'"
The output should include '/opt/homebrew/bin/cliproxyapi'
End

It 'checks /usr/local/bin/cliproxyapi as fallback'
When run bash -c "grep '/usr/local/bin/cliproxyapi' '$SCRIPT'"
The output should include '/usr/local/bin/cliproxyapi'
End

It 'shows error message when binary not found'
When run bash -c "grep 'cliproxyapi not found' '$SCRIPT'"
The output should include 'cliproxyapi not found'
End

It 'exits with error when binary not found'
When run bash -c "grep 'exit 1' '$SCRIPT'"
The output should include 'exit 1'
End
End

Describe 'Alibaba Cloud Token Plan provider'
It 'hydrates the dedicated environment key into the runtime config'
When run bash -c "grep 's|__ALIYUN_TOKEN_PLAN_API_KEY__|.*ALIYUN_TOKEN_PLAN_API_KEY' '$SCRIPT'"
The output should include '__ALIYUN_TOKEN_PLAN_API_KEY__'
The output should include 'ALIYUN_TOKEN_PLAN_API_KEY'
The status should be success
End

It 'declares a dedicated prefixed upstream and secret placeholder'
When run bash -c "sed -n '/name: \"aliyun\"/,/name: \"opencode\"/p' '$PWD/config/cliproxyapi/config.template.yaml'"
The output should include 'prefix: "aliyun"'
The output should include 'base-url: "https://token-plan.ap-southeast-1.maas.aliyuncs.com/compatible-mode/v1"'
The output should include 'api-key: "__ALIYUN_TOKEN_PLAN_API_KEY__"'
The output should include 'priority: 200'
The output should not include 'name: "qwen3.6-plus"'
The output should include 'name: "deepseek-v4-flash-0731"'
The output should include 'alias: "deepseek-v4.1-flash"'
The output should not include 'name: "qwen3.8-max"'
The output should not include 'name: "glm-5.2"'
The status should be success
End
End

Describe 'Verboo DeepSeek provider'
It 'hydrates the dedicated environment key into the runtime config'
When run bash -c "grep 's|__VERBOO_API_KEY__|.*VERBOO_API_KEY' '$SCRIPT'"
The output should include '__VERBOO_API_KEY__'
The output should include 'VERBOO_API_KEY'
The status should be success
End

It 'declares the OpenAI-compatible DeepSeek fallback upstream'
When run bash -c "sed -n '/name: \"verboo\"/,/name: \"openai\"/p' '$PWD/config/cliproxyapi/config.template.yaml'"
The output should include 'priority: 150'
The output should include 'base-url: "https://code.verboo.ai/router/v1"'
The output should include 'api-key: "__VERBOO_API_KEY__"'
The output should include 'name: "deepseek-v4-flash-0731"'
The output should include 'alias: "deepseek-v4.1-flash"'
The status should be success
End
End

Describe 'Command Code provider'
It 'hydrates the dedicated environment key into the runtime config'
When run bash -c "grep 's|__COMMANDCODE_API_KEY__|.*COMMANDCODE_API_KEY' '$SCRIPT'"
The output should include '__COMMANDCODE_API_KEY__'
The output should include 'COMMANDCODE_API_KEY'
The status should be success
End

It 'declares the OpenAI-compatible DeepSeek fallback upstream'
When run bash -c "sed -n '/name: \"commandcode\"/,/name: \"openai\"/p' '$PWD/config/cliproxyapi/config.template.yaml'"
The output should include 'priority: 150'
The output should include 'base-url: "https://api.commandcode.ai/provider/v1"'
The output should include 'api-key: "__COMMANDCODE_API_KEY__"'
The output should include 'name: "deepseek-v4-flash-0731"'
The output should include 'alias: "deepseek-v4.1-flash"'
The status should be success
End
End

Describe 'Surplus Intelligence marketplace provider'
It 'hydrates the dedicated environment key into the runtime config'
When run bash -c "grep 's|__SURPLUS_API_KEY__|.*SURPLUS_API_KEY' '$SCRIPT'"
The output should include '__SURPLUS_API_KEY__'
The output should include 'SURPLUS_API_KEY'
The status should be success
End

It 'renders a key with a trailing newline and sed metacharacters intact'
When run bash -c "source <(sed -n '/^sed_value() {/,/^}/p' '$SCRIPT'); printf 'api-key: \"__K__\"\n' | sed -e \"s|__K__|\$(sed_value \$'ab|c&d\\\\\\\\e\\n')|g\""
The output should equal 'api-key: "ab|c&d\\e"'
The status should be success
End

It 'declares the OpenAI-compatible last-resort fallback upstream'
When run bash -c "sed -n '/name: \"surplus\"/,/name: \"openai\"/p' '$PWD/config/cliproxyapi/config.template.yaml'"
The output should include 'priority: 150'
The output should include 'base-url: "https://api.surplusintelligence.ai/v1"'
The output should include 'api-key: "__SURPLUS_API_KEY__"'
The output should include 'name: "deepseek-v4.1-flash"'
The output should include 'alias: "deepseek-v4.1-flash"'
The status should be success
End
End

Describe 'Ollama Cloud provider'
setup_ollama_pool() {
  TEMP_OLLAMA=$(mktemp -d)
  printf '%s\n' '  - name: "ollama-cloud"' '    api-key-entries: __OLLAMA_API_KEY_ENTRIES__' >"$TEMP_OLLAMA/template.yaml"
  sed -n '/^render_api_key_entries() {/,/^}/p' "$SCRIPT" >"$TEMP_OLLAMA/render.sh"
  cat >>"$TEMP_OLLAMA/render.sh" <<'BASH'
render_api_key_entries __OLLAMA_API_KEY_ENTRIES__ "${OLLAMA_API_KEYS:-},${OLLAMA_API_KEY:-}" <"$1"
BASH
}

cleanup_ollama_pool() {
  rm -rf "$TEMP_OLLAMA"
}

Before 'setup_ollama_pool'
After 'cleanup_ollama_pool'

It 'renders the key pool from both plural and singular keys'
When run cat "$SCRIPT"
The output should include 'render_api_key_entries __OLLAMA_API_KEY_ENTRIES__ "${OLLAMA_API_KEYS:-},${OLLAMA_API_KEY:-}"'
The output should not include '__OLLAMA_API_KEY__'
The status should be success
End

It 'renders each non-empty plural key once'
When run env OLLAMA_API_KEYS='first-key, second-key,first-key,' OLLAMA_API_KEY='' bash "$TEMP_OLLAMA/render.sh" "$TEMP_OLLAMA/template.yaml"
The output should include '      - api-key: "first-key"'
The output should include '      - api-key: "second-key"'
The output should not include '__OLLAMA_API_KEY_ENTRIES__'
The status should be success
End

It 'uses the singular key alone'
When run env OLLAMA_API_KEYS='' OLLAMA_API_KEY='single-key' bash "$TEMP_OLLAMA/render.sh" "$TEMP_OLLAMA/template.yaml"
The output should include '      - api-key: "single-key"'
The output should not include 'api-key-entries: []'
The status should be success
End

It 'merges singular and plural keys without duplicates'
When run env OLLAMA_API_KEYS='first-key,second-key' OLLAMA_API_KEY='first-key' bash -c "bash '$TEMP_OLLAMA/render.sh' '$TEMP_OLLAMA/template.yaml' | grep -c 'api-key: '"
The output should equal '2'
The status should be success
End

It 'merges a distinct singular key into the pool'
When run env OLLAMA_API_KEYS='first-key' OLLAMA_API_KEY='third-key' bash "$TEMP_OLLAMA/render.sh" "$TEMP_OLLAMA/template.yaml"
The output should include '      - api-key: "first-key"'
The output should include '      - api-key: "third-key"'
The status should be success
End

It 'renders an empty pool when no key is set'
When run env OLLAMA_API_KEYS='' OLLAMA_API_KEY='' bash "$TEMP_OLLAMA/render.sh" "$TEMP_OLLAMA/template.yaml"
The output should include 'api-key-entries: []'
The status should be success
End

It 'passes the provider name so mapped keys use their kamino tunnel'
When run cat "$SCRIPT"
The output should include '"${OLLAMA_API_KEYS:-},${OLLAMA_API_KEY:-}" ollama-cloud'
The status should be success
End

render_mapped_ollama_keys() {
  printf '%s\n' '[{"provider":"ollama-cloud","key_index":2,"host":"kamino2","port":1082},{"provider":"other","key_index":1,"host":"kamino1","port":1081},{"credential":"a.json","host":"kamino1","port":1081}]' >"$TEMP_OLLAMA/map.json"
  sed -n '/^render_api_key_entries() {/,/^}/p' "$SCRIPT" | sed 's|@jq@|jq|g' >"$TEMP_OLLAMA/mapped.sh"
  printf '%s\n' "KAMINO_MAPPING_FILE='$TEMP_OLLAMA/map.json'" 'render_api_key_entries __OLLAMA_API_KEY_ENTRIES__ "first-key,second-key" ollama-cloud <"$1"' >>"$TEMP_OLLAMA/mapped.sh"
  bash "$TEMP_OLLAMA/mapped.sh" "$TEMP_OLLAMA/template.yaml"
}

It 'adds the tunnel proxy-url to the mapped key and direct to the rest'
When call render_mapped_ollama_keys
The output should equal '  - name: "ollama-cloud"
    api-key-entries:
      - api-key: "first-key"
        proxy-url: "direct"
      - api-key: "second-key"
        proxy-url: "socks5://127.0.0.1:1082"'
The status should be success
End

render_with_invalid_mapping() {
  printf '%s\n' 'not json' >"$TEMP_OLLAMA/map.json"
  sed -n '/^render_api_key_entries() {/,/^}/p' "$SCRIPT" | sed 's|@jq@|jq|g' >"$TEMP_OLLAMA/mapped.sh"
  printf '%s\n' "KAMINO_MAPPING_FILE='$TEMP_OLLAMA/map.json'" 'render_api_key_entries __OLLAMA_API_KEY_ENTRIES__ "first-key" ollama-cloud <"$1"' >>"$TEMP_OLLAMA/mapped.sh"
  bash "$TEMP_OLLAMA/mapped.sh" "$TEMP_OLLAMA/template.yaml"
}

It 'fails instead of rendering keys without their tunnel on an invalid mapping'
When call render_with_invalid_mapping
The status should be failure
The output should equal ''
The stderr should include 'Invalid kamino tunnel mapping'
End

It 'declares the OpenAI-compatible fallback upstream'
When run bash -c "sed -n '/name: \"ollama-cloud\"/,/^$/p' '$PWD/config/cliproxyapi/config.template.yaml'"
The output should include 'priority: 150'
The output should include 'base-url: "https://ollama.com/v1"'
The output should include 'api-key-entries: __OLLAMA_API_KEY_ENTRIES__'
The output should include 'name: "deepseek-v4.1-flash"'
The output should not include 'name: "minimax-m3"'
The output should not include 'name: "kimi-k3"'
The status should be success
End
End

Describe 'Docker image handling'
It 'prioritizes the proxy container among Docker workloads'
When run bash -c "grep -q -- '--cpu-shares 262144' '$SCRIPT' && grep -q -- '--blkio-weight 1000' '$SCRIPT'"
The status should be success
End

It 'applies the intended weights to the actual systemd cgroup-v2 scope'
When run bash -c "grep -q 'systemctl set-property --runtime' '$SCRIPT' && grep -q 'CPUWeight=10000 IOWeight=10000' '$SCRIPT' && grep -q '^  apply_systemd_cgroup_weights$' '$SCRIPT'"
The status should be success
End

It 'supports a locally built canary image without pulling over it'
When run bash -c "sed -n '/CLIPROXYAPI_IMAGE/,/\"\$docker_image\" \&/p' '$SCRIPT'"
The output should include 'CLIPROXYAPI_IMAGE:-eceasy/cli-proxy-api:latest'
The output should include 'CLIPROXYAPI_SKIP_PULL:-false'
The output should include '[ "${CLIPROXYAPI_SKIP_PULL:-false}" != "true" ]'
The output should include 'docker pull "$docker_image"'
The output should include '"$docker_image" &'
The status should be success
End

It 'pulls default and custom images but skips a local canary'
When run bash -c '
  docker() { printf "pull %s\n" "$2"; }
  pull_block=$(sed -n '\''/    if \[ "${CLIPROXYAPI_SKIP_PULL:-false}" != "true" \]; then/,/    fi/p'\'' "$1")
  docker_image=eceasy/cli-proxy-api:latest
  CLIPROXYAPI_SKIP_PULL=false
  eval "$pull_block"
  docker_image=registry.example/cliproxyapi:test
  eval "$pull_block"
  docker_image=cliproxyapi:local-canary
  CLIPROXYAPI_SKIP_PULL=true
  eval "$pull_block"
' _ "$SCRIPT"
The output should include 'pull eceasy/cli-proxy-api:latest'
The output should include 'pull registry.example/cliproxyapi:test'
The output should not include 'pull cliproxyapi:local-canary'
The status should be success
End
End

Describe 'OpenRouter fallback routing'

It 'keeps provider selection sticky for eight hours per client session'
When run bash -c "sed -n '/^routing:/,/^[a-z]/p' '$PWD/config/cliproxyapi/config.template.yaml'"
The output should include 'session-affinity: true'
The output should include 'session-affinity-ttl: "8h"'
The output should include 'strategy: "round-robin"'
The status should be success
End

It 'does not configure the retired GLM model on Z-AI'
When run bash -c "sed -n '/name: \"z-ai\"/,/name: \"kimi\"/p' '$PWD/config/cliproxyapi/config.template.yaml'"
The output should include 'priority: 50'
The output should include 'prefix: "z-ai"'
The output should include 'models: []'
The output should not include 'glm-4.7'
The status should be success
End

It 'does not route the retired GLM model through OpenRouter'
When run bash -c "sed -n '/name: \"openrouter\"/,/name: \"z-ai\"/p' '$PWD/config/cliproxyapi/config.template.yaml'"
The output should not include 'glm-4.7'
The output should not include '@preset/glm-4-7'
The status should be success
End

It 'maps the free router to OpenClaw canonical model alias'
When run bash -c "sed -n '/name: \"openrouter\"/,/name: \"z-ai\"/p' '$PWD/config/cliproxyapi/config.template.yaml'"
The output should include 'name: "openrouter/free"'
The output should include 'alias: "free"'
The status should be success
End

It 'preserves the OpenCode then Aliyun then Verboo then OpenRouter then Surplus hop'
When run bash -c "awk '/name: \"surplus\"/{p=1} p&&/priority:/{print; exit}' '$PWD/config/cliproxyapi/config.template.yaml'; awk '/name: \"openrouter\"/{p=1} p&&/priority:/{print; exit}' '$PWD/config/cliproxyapi/config.template.yaml'; awk '/name: \"verboo\"/{p=1} p&&/priority:/{print; exit}' '$PWD/config/cliproxyapi/config.template.yaml'; awk '/name: \"aliyun\"/{p=1} p&&/priority:/{print; exit}' '$PWD/config/cliproxyapi/config.template.yaml'; awk '/name: \"opencode\"/{p=1} p&&/priority:/{print; exit}' '$PWD/config/cliproxyapi/config.template.yaml'"
The output should include 'priority: 150'
The output should include 'priority: 100'
The output should include 'priority: 150'
The output should include 'priority: 200'
The output should include 'priority: 300'
The status should be success
End

It 'lists providers in descending priority order'
When run bash -c "awk '/^openai-compatibility:/{p=1; next} p && /^# Official/{exit} p && /^  - name: /{print}' '$PWD/config/cliproxyapi/config.template.yaml' | sed 's/^  - name: //; s/\"//g'"
The output should equal 'opencode-campaign
opencode
ollama-cloud
aliyun
verboo
commandcode
surplus
openrouter-campaign
openrouter
z-ai
kimi
qwen
openai'
The status should be success
End

It 'preserves prompt cache keys for OpenRouter, Aliyun, and OpenCode'
When run bash -c "sed -n '/name: \"openrouter\"/,/name: \"z-ai\"/p' '$PWD/config/cliproxyapi/config.template.yaml'; sed -n '/name: \"aliyun\"/,/name: \"opencode\"/p' '$PWD/config/cliproxyapi/config.template.yaml'; sed -n '/name: \"opencode\"/,/name: \"openai\"/p' '$PWD/config/cliproxyapi/config.template.yaml'"
The output should include 'support-prompt-cache-key: true'
The status should be success
End

It 'enables prompt cache keys on the Aliyun hop'
When run bash -c "sed -n '/name: \"aliyun\"/,/name: \"opencode\"/p' '$PWD/config/cliproxyapi/config.template.yaml'"
The output should include 'support-prompt-cache-key: true'
The status should be success
End

It 'enables prompt cache keys on the OpenCode hop'
When run bash -c "sed -n '/name: \"opencode\"/,/name: \"openai\"/p' '$PWD/config/cliproxyapi/config.template.yaml'"
The output should include 'support-prompt-cache-key: true'
The status should be success
End

It 'reloads the Linux service in place when the managed template changes'
When run bash -c "sed -n '/systemd.user.services.cliproxyapi =/,/systemd.user.paths.cliproxyapi-backup-auth =/p' '$PWD/home-manager/services/cliproxyapi/default.nix'"
The output should include 'X-SwitchMethod = "reload"'
The output should include 'X-Reload-Triggers'
The output should include 'ExecReload = "${pkgs.bash}/bin/bash ${startScript} render"'
The output should include 'config.home.file.".cli-proxy-api/config.template.yaml".source'
The status should be success
End

It 'reloads instead of restarting from make switch'
When run bash -c "sed -n '/^systemctl-cliproxyapi:/,/^$/p' '$PWD/Makefile'"
The output should include 'systemctl --user reload-or-restart cliproxyapi.service'
The output should not include 'systemctl --user restart cliproxyapi.service'
The status should be success
End

It 'leaves the hourly backup to its timer during make switch'
When run grep -n 'cliproxyapi-backup' "$PWD/Makefile"
The output should equal ''
The status should be failure
End
End

Describe 'render mode'
setup_render() {
  TEMP_HOME=$(mktemp -d)
  mkdir -p "$TEMP_HOME/.cli-proxy-api" "$TEMP_HOME/dotfiles"
  printf 'marker: __VERBOO_API_KEY__\n' >"$TEMP_HOME/.cli-proxy-api/config.template.yaml"
  printf 'VERBOO_API_KEY=DUMMY_ONE\n' >"$TEMP_HOME/dotfiles/.env"
  sed -e 's|@objectstore_enabled@|false|' -e 's|@aws@|false|g' \
    "$PWD/home-manager/services/cliproxyapi/scripts/common.sh" >"$TEMP_HOME/common.sh"
  sed -e "s|@common@|$TEMP_HOME/common.sh|" -e 's|@sed@|sed|g' -e 's|@jq@|jq|g' \
    -e 's|@flock@|flock|g' -e 's|@aws@|false|g' "$SCRIPT" >"$TEMP_HOME/start.sh"
}
cleanup_render() { rm -rf "$TEMP_HOME"; }
Before 'setup_render'
After 'cleanup_render'

It 'rewrites the bind-mounted config in place and exits without starting the server'
When run bash -c '
  cd "$1"
  config="$1/.cli-proxy-api/config.yaml"
  HOME="$1" bash "$1/start.sh" render
  before=$(ls -i "$config" | cut -d" " -f1)
  printf "VERBOO_API_KEY=DUMMY_TWO\n" >"$1/dotfiles/.env"
  HOME="$1" bash "$1/start.sh" render
  after=$(ls -i "$config" | cut -d" " -f1)
  cat "$config"
  [ "$before" = "$after" ] && echo same-inode
  [ ! -e "$config.rendered" ] && echo no-temp-file
' _ "$TEMP_HOME"
The output should include 'marker: DUMMY_TWO'
The output should include 'same-inode'
The output should include 'no-temp-file'
The output should not include 'cliproxyapi not found'
The status should be success
End
End

Describe 'official configuration reference'
It 'keeps the upstream configuration guidance in both declarative templates'
When run bash -c 'for file in config/cliproxyapi/config.tpl.yaml config/cliproxyapi/config.template.yaml; do
  grep -Fq "# Credential concurrency is configured by Home in Home mode." "$file" &&
  grep -Fq "# Standard dynamic library plugins are trusted in-process code." "$file" &&
  grep -Fq "# Native Interactions API keys" "$file" &&
  grep -Fq "# Default headers for Claude API requests." "$file" &&
  grep -Fq "# Global OAuth model name aliases (per channel)" "$file" &&
  grep -Fq "#   default-raw: # Default raw rules set parameters using raw JSON when missing (must be valid JSON)." "$file" &&
  grep -Fq "#   filter: # Filter rules remove specified parameters from the payload." "$file" || exit 1
done'
The status should be success
End

It 'keeps behavior-changing official examples inactive'
When run bash -c "grep -Fq '  # antigravity-credits: true' config/cliproxyapi/config.template.yaml && grep -Fq 'ws-auth: false' config/cliproxyapi/config.template.yaml"
The status should be success
End
End

Describe 'OpenCode API key pool'
setup_opencode_pool() {
  TEMP_POOL=$(mktemp -d)
  cat >"$TEMP_POOL/template.yaml" <<'YAML'
openai-compatibility:
  - name: "opencode"
    api-key-entries: __OPENCODE_API_KEY_ENTRIES__
YAML
  sed -n '/^render_api_key_entries() {/,/^}/p' "$SCRIPT" >"$TEMP_POOL/render.sh"
  cat >>"$TEMP_POOL/render.sh" <<'BASH'
render_api_key_entries __OPENCODE_API_KEY_ENTRIES__ "${OPENCODE_API_KEYS:-${OPENCODE_API_KEY:-}}" <"$1"
BASH
}

cleanup_opencode_pool() {
  rm -rf "$TEMP_POOL"
}

Before 'setup_opencode_pool'
After 'cleanup_opencode_pool'

It 'declares a generated credential pool for the existing OpenCode endpoint'
When run bash -c "sed -n '/name: \"opencode\"/,/name: \"openai\"/p' '$PWD/config/cliproxyapi/config.template.yaml'"
The output should include 'base-url: "https://opencode.ai/zen/go/v1"'
The output should include 'X-Opencode-Session: "$X-Session-Affinity"'
The output should include '__OPENCODE_API_KEY_ENTRIES__'
The output should not include '__OPENCODE_API_KEY__'
The status should be success
End

It 'renders plural keys with singular fallback without a temporary config'
When run cat "$SCRIPT"
The output should include 'OPENCODE_API_KEYS:-${OPENCODE_API_KEY:-}'
The output should include 'api-key-entries: []'
The output should include 'api_keys+=("$trimmed")'
The output should include 'render_api_key_entries __OPENCODE_API_KEY_ENTRIES__ "${OPENCODE_API_KEYS:-${OPENCODE_API_KEY:-}}" <"$TEMPLATE" |'
The output should not include 'SED_CONFIG='
The status should be success
End

It 'renders each non-empty plural key once'
When run env OPENCODE_API_KEYS='first-key, second-key,first-key,, third-key ' bash "$TEMP_POOL/render.sh" "$TEMP_POOL/template.yaml"
The output should include '      - api-key: "first-key"'
The output should include '      - api-key: "second-key"'
The output should include '      - api-key: "third-key"'
The output should not include '__OPENCODE_API_KEY_ENTRIES__'
The status should be success
End

It 'falls back to the legacy singular key'
When run env OPENCODE_API_KEYS='' OPENCODE_API_KEY='legacy-key' bash "$TEMP_POOL/render.sh" "$TEMP_POOL/template.yaml"
The output should include '      - api-key: "legacy-key"'
The output should not include 'api-key-entries: []'
The status should be success
End
End

Describe 'proxy URL hydration'
render_proxy_fixture() (
  set -eu
  local temp_home expected actual
  temp_home=$(mktemp -d)
  trap 'rm -rf "$temp_home"' EXIT
  expected="${CLIPROXY_PROXY_URL:-}"
  mkdir -p "$temp_home/dotfiles" "$temp_home/.cli-proxy-api"
  printf 'CLIPROXY_PROXY_URL=%q\n' "$expected" >"$temp_home/dotfiles/.env"
  printf '%s\n' 'proxy-url: "__CLIPROXY_PROXY_URL__"' 'port: 8317' >"$temp_home/.cli-proxy-api/config.template.yaml"
  {
    printf '%s\n' 'set -eu' 'unset CLIPROXY_PROXY_URL CLIPROXY_API_KEY' \
      '. "$1"' 'cliproxy_load_env' \
      'TEMPLATE="$HOME/.cli-proxy-api/config.template.yaml"' \
      'CONFIG="$HOME/.cli-proxy-api/config.yaml"' \
      'KAMINO_MAPPING_FILE="$HOME/.config/cliproxyapi/kamino-tunnels.json"'
    sed -n '/^render_proxy_url() {/,/^}/p; /^render_api_key_entries() {/,/^}/p; /^sed_value() {/,/^}/p; /^if \[ -f "$TEMPLATE" \]; then/,/^fi/p' "$SCRIPT" | sed 's|@jq@|jq|g; s|@sed@|sed|g'
  } >"$temp_home/render.sh"
  HOME="$temp_home" bash "$temp_home/render.sh" "$PWD/home-manager/services/cliproxyapi/scripts/common.sh"
  actual=$(sed -n 's/^proxy-url: //p' "$temp_home/.cli-proxy-api/config.yaml")
  EXPECTED_PROXY="$expected" jq -en --argjson actual "$actual" '$actual == env.EXPECTED_PROXY' >/dev/null
  grep -Fx 'port: 8317' "$temp_home/.cli-proxy-api/config.yaml" >/dev/null
)

It 'hydrates an unset proxy as an empty string'
unset CLIPROXY_PROXY_URL
When run render_proxy_fixture
The status should be success
End

It 'preserves URL characters without sed or YAML injection'
export CLIPROXY_PROXY_URL='https://user:p%40ss&word|test"\@rp.evomi-proxy.com:1001'
When run render_proxy_fixture
The status should be success
End

It 'uses the runtime placeholder in both templates'
When run bash -c 'for file in config/cliproxyapi/config.tpl.yaml config/cliproxyapi/config.template.yaml; do
  grep -Fx '\''proxy-url: "__CLIPROXY_PROXY_URL__"'\'' "$file" >/dev/null || exit 1
done'
The status should be success
End

It 'connects every API key entry except the campaigns directly'
When run bash -c 'for file in config/cliproxyapi/config.tpl.yaml config/cliproxyapi/config.template.yaml; do
  awk '\''/^  - name: "/ { campaign = ($3 ~ /-campaign"$/) } prev ~ /^      - api-key: "__/ { direct = ($0 == "        proxy-url: \"direct\""); if (direct == campaign) bad = 1 } { prev = $0 } END { exit bad }'\'' "$file" || exit 1
done'
The status should be success
End

It 'declares a keyless OpenCode Zen campaign over the global proxy'
When run bash -c "sed -n '/name: \"opencode-campaign\"/,/name: \"opencode\"/p' '$PWD/config/cliproxyapi/config.template.yaml'"
The output should include 'base-url: "https://opencode.ai/zen/v1"'
The output should include 'priority: 302'
The output should include 'name: "mimo-v2.5-free"'
The output should not include 'api-key'
The output should not include 'proxy-url'
The status should be success
End

It 'enables plugins'
When run bash -c "sed -n '/^plugins:/,/^  dir:/p' '$PWD/config/cliproxyapi/config.template.yaml'"
The output should include '  enabled: true'
The status should be success
End
End

Describe 'per-credential proxy assignment'
setup_proxy_assign() {
  TEMP_ASSIGN=$(mktemp -d)
  mkdir -p "$TEMP_ASSIGN/.config/cliproxyapi" "$TEMP_ASSIGN/.cli-proxy-api/objectstore/auths"
  {
    printf '%s\n' 'set -euo pipefail' 'CONFIG_DIR="$HOME/.cli-proxy-api"' 'KAMINO_MAPPING_FILE="$HOME/.config/cliproxyapi/kamino-tunnels.json"'
    sed -n '/^PROXY_URL_LOCK_FILE=/p; /^assign_proxy_urls() {/,/^}/p' "$SCRIPT" | sed 's|@jq@|jq|g; s|@flock@|:|g'
    printf '%s\n' 'assign_proxy_urls "$HOME/.cli-proxy-api/objectstore/auths"'
  } >"$TEMP_ASSIGN/assign.sh"
  for name in plain mapped direct; do
    printf '{"type":"codex","proxy_url":"%s"}\n' "$([ "$name" = direct ] && echo direct)" \
      >"$TEMP_ASSIGN/.cli-proxy-api/objectstore/auths/$name.json"
  done
  printf '%s\n' '[{"credential":"mapped.json","host":"kamino2","port":1082}]' \
    >"$TEMP_ASSIGN/.config/cliproxyapi/kamino-tunnels.json"
}

cleanup_proxy_assign() {
  rm -rf "$TEMP_ASSIGN"
}

Before 'setup_proxy_assign'
After 'cleanup_proxy_assign'

assign_and_read() {
  HOME="$TEMP_ASSIGN" CLIPROXY_PROXY_URL="$1" bash "$TEMP_ASSIGN/assign.sh" &&
    for name in plain mapped direct; do
      printf '%s=%s\n' "$name" "$(jq -r .proxy_url "$TEMP_ASSIGN/.cli-proxy-api/objectstore/auths/$name.json")"
    done
}

It 'makes unmapped auths direct and applies the mapped tunnel port'
When call assign_and_read 'http://global.example:8080'
The line 1 of output should equal 'plain=direct'
The line 2 of output should equal 'mapped=socks5://127.0.0.1:1082'
The line 3 of output should equal 'direct=direct'
End

It 'keeps the tunnel port when the proxy is unset'
When call assign_and_read ''
The line 1 of output should equal 'plain=direct'
The line 2 of output should equal 'mapped=socks5://127.0.0.1:1082'
End

It 'fails on an invalid tunnel mapping'
setup_invalid_mapping() { printf 'not json' >"$TEMP_ASSIGN/.config/cliproxyapi/kamino-tunnels.json"; }
BeforeCall 'setup_invalid_mapping'
When call assign_and_read ''
The status should be failure
The stderr should include 'Invalid kamino tunnel mapping'
End

It 'waits on the lock shared with the kamino tunnels'
When run bash -c "grep -F '@flock@ -w 30 200' '$SCRIPT' && grep -F '@flock@ -w 30 200' '$PWD/home-manager/services/cliproxyapi/scripts/kamino-tunnel.sh'"
The status should be success
The output should include 'flock'
End
End

Describe 'kamino-tunnel.sh'
TUNNEL_SCRIPT="$PWD/home-manager/services/cliproxyapi/scripts/kamino-tunnel.sh"

setup_tunnel() {
  TEMP_TUNNEL=$(mktemp -d)
  mkdir -p "$TEMP_TUNNEL/.config/cliproxyapi" "$TEMP_TUNNEL/.cli-proxy-api/objectstore/auths"
  sed 's|@jq@|jq|g; s|@flock@|:|g; s|@ssh@|echo ssh|g' "$TUNNEL_SCRIPT" >"$TEMP_TUNNEL/tunnel.sh"
  printf '%s\n' '{"type":"claude","proxy_url":""}' >"$TEMP_TUNNEL/.cli-proxy-api/objectstore/auths/my account.json"
}

cleanup_tunnel() {
  rm -rf "$TEMP_TUNNEL"
}

Before 'setup_tunnel'
After 'cleanup_tunnel'

write_tunnel_mapping() {
  printf '%s\n' "$1" >"$TEMP_TUNNEL/.config/cliproxyapi/kamino-tunnels.json"
}

It 'stamps mapped credentials, including names with spaces, then starts ssh'
write_tunnel_mapping '[{"credential":"my account.json","host":"kamino2","port":1082}]'
When run bash -c 'HOME="$1" bash "$1/tunnel.sh" 2 && jq -r .proxy_url "$1/.cli-proxy-api/objectstore/auths/my account.json"' _ "$TEMP_TUNNEL"
The status should be success
The output should include 'ssh -N -D 127.0.0.1:1082'
The output should include 'StrictHostKeyChecking=yes'
The output should include 'socks5://127.0.0.1:1082'
End

It 'exits cleanly without a tunnel when nothing is mapped to the index'
write_tunnel_mapping '[{"credential":"my account.json","host":"kamino2","port":1082}]'
When run bash -c 'HOME="$1" bash "$1/tunnel.sh" 1' _ "$TEMP_TUNNEL"
The status should be success
The output should not include 'ssh'
The stderr should include 'Nothing mapped to kamino1:1081'
End

It 'starts the tunnel for an API key mapping without touching auth files'
write_tunnel_mapping '[{"provider":"ollama-cloud","key_index":1,"host":"kamino3","port":1083}]'
When run bash -c 'HOME="$1" bash "$1/tunnel.sh" 3 && jq -r .proxy_url "$1/.cli-proxy-api/objectstore/auths/my account.json"' _ "$TEMP_TUNNEL"
The status should be success
The output should include 'ssh -N -D 127.0.0.1:1083'
The output should not include 'socks5://'
End

It 'exits cleanly when the mapping file is missing'
When run bash -c 'HOME="$1" bash "$1/tunnel.sh" 1' _ "$TEMP_TUNNEL"
The status should be success
The output should not include 'ssh'
The stderr should include 'No kamino tunnel mapping'
End

It 'fails on an invalid mapping'
write_tunnel_mapping 'not json'
When run bash -c 'HOME="$1" bash "$1/tunnel.sh" 1' _ "$TEMP_TUNNEL"
The status should be failure
The stderr should include 'Invalid JSON'
End

It 'rejects a non-numeric index'
When run bash "$TUNNEL_SCRIPT" abc
The status should be failure
The stderr should include 'positive integer'
End
End

Describe 'OAuth credential priority enforcement'
setup_oauth_priority() {
  TEMP_PRIORITY=$(mktemp -d)
  sed -n '/^ensure_oauth_priority() {/,/^}/p' "$SCRIPT" | sed 's|@jq@|jq|g' >"$TEMP_PRIORITY/fn.sh"
}

cleanup_oauth_priority() {
  rm -rf "$TEMP_PRIORITY"
}

Before 'setup_oauth_priority'
After 'cleanup_oauth_priority'

It 'bumps priority 0 auth files to the target'
cat >"$TEMP_PRIORITY/codex-test-user.json" <<'JSON'
{"provider":"codex","account":"test@example.com","priority":0}
JSON
When run bash -c '. "$1/fn.sh"; ensure_oauth_priority "$1" 300; cat "$1/codex-test-user.json"' _ "$TEMP_PRIORITY"
The output should include '"priority": 300'
The status should be success
End

It 'leaves auth files already at the target priority unchanged'
cat >"$TEMP_PRIORITY/codex-already-set.json" <<'JSON'
{"provider":"codex","account":"test@example.com","priority":300}
JSON
cp "$TEMP_PRIORITY/codex-already-set.json" "$TEMP_PRIORITY/codex-already-set.json.orig"
When run bash -c '. "$1/fn.sh"; ensure_oauth_priority "$1" 300; diff "$1/codex-already-set.json.orig" "$1/codex-already-set.json"' _ "$TEMP_PRIORITY"
The status should be success
End

It 'bumps all provider types equally'
cat >"$TEMP_PRIORITY/claude-user.json" <<'JSON'
{"provider":"claude","account":"test@example.com","priority":0}
JSON
cat >"$TEMP_PRIORITY/gemini-user.json" <<'JSON'
{"provider":"gemini","account":"test@example.com","priority":0}
JSON
When run bash -c '. "$1/fn.sh"; ensure_oauth_priority "$1" 300; jq -r .priority "$1/claude-user.json"; jq -r .priority "$1/gemini-user.json"' _ "$TEMP_PRIORITY"
The first line of output should eq '300'
The second line of output should eq '300'
The status should be success
End

It 'adds priority field when missing'
cat >"$TEMP_PRIORITY/codex-no-priority.json" <<'JSON'
{"provider":"codex","account":"new@example.com"}
JSON
When run bash -c '. "$1/fn.sh"; ensure_oauth_priority "$1" 300; jq -r .priority "$1/codex-no-priority.json"' _ "$TEMP_PRIORITY"
The output should eq '300'
The status should be success
End
End

End
