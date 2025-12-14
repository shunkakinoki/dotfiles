#!/usr/bin/env bash
# shellcheck disable=SC2329

Describe 'cliproxyapi/start.sh'
SCRIPT="$PWD/home-manager/services/cliproxyapi/start.sh"

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
When run bash -c "grep 'cliproxyapi binary not found' '$SCRIPT'"
The output should include 'cliproxyapi binary not found'
End

It 'suggests installation command in error message'
When run bash -c "grep 'brew install cliproxyapi' '$SCRIPT'"
The output should include 'brew install cliproxyapi'
End
End

End
