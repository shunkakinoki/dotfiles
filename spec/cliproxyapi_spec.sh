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
management_password: __CLIPROXY_MANAGEMENT_PASSWORD__
YAML

  # Create .env file
  cat >"$TEMP_HOME/dotfiles/.env" <<'ENV'
OPENROUTER_API_KEY=test_openrouter_key
OPENAI_API_KEY=test_openai_key
QWEN_API_KEY=test_qwen_key
ALIYUN_TOKEN_PLAN_API_KEY=test_token_plan_key
VERBOO_API_KEY=test_verboo_key
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
CLIPROXY_MANAGEMENT_PASSWORD="test_pass"

if [ -f "$TEMPLATE" ]; then
  sed -e "s|__OPENROUTER_API_KEY__|${OPENROUTER_API_KEY:-}|g" \
    -e "s|__OPENAI_API_KEY__|${OPENAI_API_KEY:-}|g" \
    -e "s|__QWEN_API_KEY__|${QWEN_API_KEY:-}|g" \
    -e "s|__ALIYUN_TOKEN_PLAN_API_KEY__|${ALIYUN_TOKEN_PLAN_API_KEY:-}|g" \
    -e "s|__VERBOO_API_KEY__|${VERBOO_API_KEY:-}|g" \
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
The output should include 'name: "qwen3.6-plus"'
The output should include 'name: "deepseek-v4-pro"'
The output should include 'name: "deepseek-v4-flash-0731"'
The output should include 'alias: "deepseek-v4-flash"'
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
The output should include 'name: "deepseek-v4-pro"'
The output should include 'name: "deepseek-v4-flash"'
The status should be success
End
End

Describe 'Docker image handling'
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
The output should include 'strategy: "fill-first"'
The status should be success
End

It 'maps the free router to OpenClaw canonical model alias'
When run bash -c "sed -n '/name: \"openrouter\"/,/name: \"z-ai\"/p' '$PWD/config/cliproxyapi/config.template.yaml'"
The output should include 'name: "openrouter/free"'
The output should include 'alias: "free"'
The status should be success
End

It 'preserves the OpenCode then Aliyun then Verboo then OpenRouter hop'
When run bash -c "awk '/name: \"openrouter\"/{p=1} p&&/priority:/{print; exit}' '$PWD/config/cliproxyapi/config.template.yaml'; awk '/name: \"verboo\"/{p=1} p&&/priority:/{print; exit}' '$PWD/config/cliproxyapi/config.template.yaml'; awk '/name: \"aliyun\"/{p=1} p&&/priority:/{print; exit}' '$PWD/config/cliproxyapi/config.template.yaml'; awk '/name: \"opencode\"/{p=1} p&&/priority:/{print; exit}' '$PWD/config/cliproxyapi/config.template.yaml'"
The output should include 'priority: 100'
The output should include 'priority: 150'
The output should include 'priority: 200'
The output should include 'priority: 300'
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

It 'restarts the Linux service when the managed template changes'
When run bash -c "sed -n '/systemd.user.services.cliproxyapi =/,/systemd.user.paths.cliproxyapi-backup =/p' '$PWD/home-manager/services/cliproxyapi/default.nix'"
The output should include 'X-Restart-Triggers'
The output should include 'config.home.file.".cli-proxy-api/config.template.yaml".source'
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
When run bash -c "grep -Fq '  # antigravity-credits: true' config/cliproxyapi/config.template.yaml && grep -Fq 'ws-auth: false' config/cliproxyapi/config.template.yaml && grep -Fq 'strategy: \"fill-first\"' config/cliproxyapi/config.template.yaml"
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
  sed -n '/^render_opencode_api_key_entries() {/,/^}/p' "$SCRIPT" >"$TEMP_POOL/render.sh"
  cat >>"$TEMP_POOL/render.sh" <<'BASH'
render_opencode_api_key_entries "$1"
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
The output should include '__OPENCODE_API_KEY_ENTRIES__'
The output should not include '__OPENCODE_API_KEY__'
The status should be success
End

It 'renders plural keys with singular fallback without a temporary config'
When run cat "$SCRIPT"
The output should include 'OPENCODE_API_KEYS:-${OPENCODE_API_KEY:-}'
The output should include 'api-key-entries: []'
The output should include 'api_keys+=("$trimmed")'
The output should include 'render_opencode_api_key_entries "$TEMPLATE" | @sed@'
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

End
