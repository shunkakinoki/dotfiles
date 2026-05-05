#!/usr/bin/env bash
# shellcheck disable=SC2329

Describe 'config/openclaw/hydrate.sh'
SCRIPT="$PWD/config/openclaw/hydrate.sh"

Describe 'script properties'
It 'uses bash shebang'
When run bash -c "head -1 '$SCRIPT'"
The output should include '#!/usr/bin/env bash'
End

It 'uses strict mode'
When run bash -c "head -5 '$SCRIPT'"
The output should include 'set -euo pipefail'
End
End

Describe 'directory configuration'
It 'uses ~/.openclaw for state directory'
When run bash -c "grep 'STATE_DIR=' '$SCRIPT'"
The output should include '.openclaw'
End

It 'uses ~/.config/openclaw for secrets'
When run bash -c "grep 'SECRETS_DIR=' '$SCRIPT'"
The output should include '.config/openclaw'
End

It 'reads from dotfiles .env file'
When run bash -c "grep 'ENV_FILE=' '$SCRIPT'"
The output should include 'dotfiles/.env'
End

It 'uses cliproxyapi config as the Kyber source of truth'
When run bash -c "grep 'CLIPROXY_CONFIG=' '$SCRIPT'"
The output should include '.cli-proxy-api/config.yaml'
End
End

Describe 'secret loading'
It 'loads CLIPROXY_API_KEY from cliproxyapi config root'
When run bash -c "grep 'read_cliproxy_api_key_from_config' '$SCRIPT'"
The output should include 'read_cliproxy_api_key_from_config'
End

It 'falls back to cliproxy key file'
When run bash -c "grep 'CLIPROXY_API_KEY' '$SCRIPT'"
The output should include 'cliproxy-key'
End

It 'loads TELEGRAM_TOKEN from file'
When run bash -c "grep 'TELEGRAM_TOKEN' '$SCRIPT'"
The output should include 'telegram-token'
End

It 'loads GATEWAY_TOKEN from file'
When run bash -c "grep 'GATEWAY_TOKEN' '$SCRIPT'"
The output should include 'gateway-token'
End

It 'loads ANTHROPIC_API_KEY from file'
When run bash -c "grep 'ANTHROPIC_API_KEY' '$SCRIPT'"
The output should include 'anthropic-key'
End

It 'loads WHATSAPP_ALLOW_FROM from file'
When run bash -c "grep 'WHATSAPP_ALLOW_FROM' '$SCRIPT'"
The output should include 'whatsapp-allow-from'
End
End

Describe 'gateway api key resolution'
setup_gateway() {
  TEMP_HOME=$(mktemp -d)
  mkdir -p "$TEMP_HOME/.cli-proxy-api"
  mkdir -p "$TEMP_HOME/.config/openclaw"
  mkdir -p "$TEMP_HOME/openclaw/bin"
  mkdir -p "$TEMP_HOME/chromium/bin"
  mkdir -p "$TEMP_HOME/templates"

  cat >"$TEMP_HOME/.cli-proxy-api/config.yaml" <<'YAML'
api-keys:
  - "from-cliproxy-config"
YAML

  cat >"$TEMP_HOME/.config/openclaw/gateway-token" <<'EOF'
gateway-token
EOF

  cat >"$TEMP_HOME/.config/openclaw/cliproxy-key" <<'EOF'
from-secret-file
EOF

  cat >"$TEMP_HOME/templates/openclaw.json" <<'EOF'
{"apiKey":"__CLIPROXY_API_KEY__","token":"__GATEWAY_TOKEN__","workspace":"__WORKSPACE__","home":"__HOME__","chromium":"__CHROMIUM_PATH__"}
EOF

  cat >"$TEMP_HOME/openclaw/bin/openclaw" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
  chmod +x "$TEMP_HOME/openclaw/bin/openclaw"

  cat >"$TEMP_HOME/chromium/bin/chromium" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
  chmod +x "$TEMP_HOME/chromium/bin/chromium"

  echo "fake-soul" >"$TEMP_HOME/SOUL.md"

  PREPROCESSED_SCRIPT="$TEMP_HOME/hydrate.sh"
  sed \
    -e 's|@mode@|gateway|g' \
    -e 's|@sed@|sed|g' \
    -e 's|@awk@|awk|g' \
    -e 's|@template@|'"$TEMP_HOME"'/templates/openclaw.json|g' \
    -e 's|@chromium@|'"$TEMP_HOME"'/chromium|g' \
    -e 's|@soul@|'"$TEMP_HOME"'/SOUL.md|g' \
    "$SCRIPT" >"$PREPROCESSED_SCRIPT"
  chmod +x "$PREPROCESSED_SCRIPT"
}

cleanup_gateway() {
  rm -rf "$TEMP_HOME"
}

Before 'setup_gateway'
After 'cleanup_gateway'

It 'prefers the root api-keys entry from cliproxyapi config over the secret file'
When run bash -c 'HOME="'"$TEMP_HOME"'" OPENCLAW_CONFIG_PATH="'"$TEMP_HOME"'/generated-openclaw.json" bash "'"$PREPROCESSED_SCRIPT"'" >/dev/null 2>&1; cat "'"$TEMP_HOME"'/generated-openclaw.json"'
The status should be success
The output should include 'from-cliproxy-config'
The output should not include 'from-secret-file'
End
End

Describe 'client config generation'
setup_client() {
  TEMP_HOME=$(mktemp -d)
  mkdir -p "$TEMP_HOME/.config/openclaw"

  cat >"$TEMP_HOME/.config/openclaw/gateway-token" <<'EOF'
gateway-token
EOF

  echo "fake-soul" >"$TEMP_HOME/SOUL.md"

  PREPROCESSED_SCRIPT="$TEMP_HOME/hydrate.sh"
  sed \
    -e 's|@mode@|client|g' \
    -e 's|@sed@|sed|g' \
    -e 's|@awk@|awk|g' \
    -e 's|@template@|/unused|g' \
    -e 's|@chromium@|/unused|g' \
    -e 's|@soul@|'"$TEMP_HOME"'/SOUL.md|g' \
    "$SCRIPT" >"$PREPROCESSED_SCRIPT"
  chmod +x "$PREPROCESSED_SCRIPT"
}

cleanup_client() {
  rm -rf "$TEMP_HOME"
}

Before 'setup_client'
After 'cleanup_client'

It 'writes the Tailscale Serve URL without the gateway port'
When run bash -c 'HOME="'"$TEMP_HOME"'" OPENCLAW_CONFIG_PATH="'"$TEMP_HOME"'/generated-openclaw.json" bash "'"$PREPROCESSED_SCRIPT"'" >/dev/null 2>&1; cat "'"$TEMP_HOME"'/generated-openclaw.json"'
The status should be success
The output should include '"transport": "direct"'
The output should include '"url": "wss://kyber.tail950b36.ts.net"'
The output should not include '18789'
End
End

Describe 'config generation'
It 'uses sed to substitute values in template'
When run bash -c "grep '@sed@' '$SCRIPT'"
The output should include '@sed@'
End

It 'substitutes CLIPROXY_API_KEY in template'
When run bash -c "grep '__CLIPROXY_API_KEY__' '$SCRIPT'"
The output should include 'CLIPROXY_API_KEY'
End

It 'substitutes TELEGRAM_TOKEN in template'
When run bash -c "grep '__TELEGRAM_TOKEN__' '$SCRIPT'"
The output should include 'TELEGRAM_TOKEN'
End

It 'substitutes WHATSAPP_ALLOW_FROM in template'
When run bash -c "grep '__WHATSAPP_ALLOW_FROM__' '$SCRIPT'"
The output should include 'WHATSAPP_ALLOW_FROM'
End

It 'creates state directory'
When run bash -c "grep 'mkdir -p' '$SCRIPT'"
The output should include 'STATE_DIR'
End
End

Describe 'execution'
It 'generates config without starting gateway'
When run bash -c "grep 'Generated openclaw gateway config' '$SCRIPT'"
The output should include 'Generated openclaw gateway config'
End
End

End
