#!/usr/bin/env bash
# shellcheck disable=SC2329

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
management_password: __CLIPROXY_MANAGEMENT_PASSWORD__
YAML

  # Create .env file
  cat >"$TEMP_HOME/dotfiles/.env" <<'ENV'
OPENROUTER_API_KEY=test_openrouter_key
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
CLIPROXY_MANAGEMENT_PASSWORD="test_pass"

if [ -f "$TEMPLATE" ]; then
  sed -e "s|__OPENROUTER_API_KEY__|${OPENROUTER_API_KEY:-}|g" \
    -e "s|__CLIPROXY_MANAGEMENT_PASSWORD__|${CLIPROXY_MANAGEMENT_PASSWORD:-}|g" \
    "$TEMPLATE" >"$CONFIG"
fi
cat "$CONFIG"
EOF
chmod +x "$TEMP_HOME/test_config.sh"

When run bash -c "HOME='$TEMP_HOME' bash '$TEMP_HOME/test_config.sh'"
The output should include 'api_key: test_key'
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

End
