#!/usr/bin/env bash
# shellcheck disable=SC2329

Describe 'config/hermes/hydrate.sh'
SCRIPT="$PWD/config/hermes/hydrate.sh"

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
It 'uses ~/.hermes for state directory'
When run bash -c "grep 'STATE_DIR=' '$SCRIPT'"
The output should include '.hermes'
End

It 'uses ~/.config/hermes for secrets'
When run bash -c "grep 'SECRETS_DIR=' '$SCRIPT'"
The output should include '.config/hermes'
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

It 'loads WHATSAPP_ALLOW_FROM from file'
When run bash -c "grep 'WHATSAPP_ALLOW_FROM' '$SCRIPT'"
The output should include 'whatsapp-allow-from'
End

It 'loads Vercel billing credentials from files'
When run bash -c "grep -E 'VERCEL_(TOKEN|TEAM_ID)' '$SCRIPT'"
The output should include 'vercel-token'
The output should include 'vercel-team-id'
End
End

Describe 'gateway config generation'
setup_gateway() {
  TEMP_HOME=$(mktemp -d)
  mkdir -p "$TEMP_HOME/.cli-proxy-api"
  mkdir -p "$TEMP_HOME/.config/hermes"
  mkdir -p "$TEMP_HOME/templates"

  cat >"$TEMP_HOME/.cli-proxy-api/config.yaml" <<'YAML'
api-keys:
  - "from-cliproxy-config"
YAML

  cat >"$TEMP_HOME/.config/hermes/gateway-token" <<'EOF'
gateway-token
EOF

  cat >"$TEMP_HOME/.config/hermes/cliproxy-key" <<'EOF'
from-secret-file
EOF

  cat >"$TEMP_HOME/.config/hermes/vercel-token" <<'EOF'
vercel-token
EOF

  cat >"$TEMP_HOME/.config/hermes/vercel-team-id" <<'EOF'
team_test
EOF

  cat >"$TEMP_HOME/templates/config.template.yaml" <<'EOF'
custom_providers:
- name: cliproxy
  api_key: __CLIPROXY_API_KEY__
EOF

  cat >"$TEMP_HOME/templates/env.template" <<'EOF'
TELEGRAM_BOT_TOKEN=__TELEGRAM_TOKEN__
WHATSAPP_ALLOWED_USERS=__WHATSAPP_ALLOW_FROM__
HERMES_GATEWAY_TOKEN=__GATEWAY_TOKEN__
CLIPROXY_API_KEY=__CLIPROXY_API_KEY__
VERCEL_TOKEN=__VERCEL_TOKEN__
VERCEL_TEAM_ID=__VERCEL_TEAM_ID__
EOF

  echo "fake-soul" >"$TEMP_HOME/SOUL.md"

  PREPROCESSED_SCRIPT="$TEMP_HOME/hydrate.sh"
  sed \
    -e 's|@mode@|gateway|g' \
    -e 's|@sed@|sed|g' \
    -e 's|@awk@|awk|g' \
    -e 's|@configTemplate@|'"$TEMP_HOME"'/templates/config.template.yaml|g' \
    -e 's|@envTemplate@|'"$TEMP_HOME"'/templates/env.template|g' \
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
When run bash -c 'unset CLIPROXY_API_KEY HERMES_GATEWAY_TOKEN GATEWAY_TOKEN HERMES_TELEGRAM_TOKEN TELEGRAM_TOKEN WHATSAPP_ALLOW_FROM VERCEL_TOKEN VERCEL_TEAM_ID; HOME="'"$TEMP_HOME"'" bash "'"$PREPROCESSED_SCRIPT"'" >/dev/null 2>&1; cat "'"$TEMP_HOME"'/.hermes/config.yaml"'
The status should be success
The output should include 'from-cliproxy-config'
The output should not include 'from-secret-file'
End

It 'writes .env with gateway token'
When run bash -c 'unset CLIPROXY_API_KEY HERMES_GATEWAY_TOKEN GATEWAY_TOKEN HERMES_TELEGRAM_TOKEN TELEGRAM_TOKEN WHATSAPP_ALLOW_FROM VERCEL_TOKEN VERCEL_TEAM_ID; HOME="'"$TEMP_HOME"'" bash "'"$PREPROCESSED_SCRIPT"'" >/dev/null 2>&1; cat "'"$TEMP_HOME"'/.hermes/.env"'
The status should be success
The output should include 'HERMES_GATEWAY_TOKEN=gateway-token'
End

It 'writes .env with Vercel billing credentials'
When run bash -c 'unset CLIPROXY_API_KEY HERMES_GATEWAY_TOKEN GATEWAY_TOKEN HERMES_TELEGRAM_TOKEN TELEGRAM_TOKEN WHATSAPP_ALLOW_FROM VERCEL_TOKEN VERCEL_TEAM_ID; HOME="'"$TEMP_HOME"'" bash "'"$PREPROCESSED_SCRIPT"'" >/dev/null 2>&1; cat "'"$TEMP_HOME"'/.hermes/.env"'
The status should be success
The output should include 'VERCEL_TOKEN=vercel-token'
The output should include 'VERCEL_TEAM_ID=team_test'
End
End

Describe 'config generation'
It 'uses sed to substitute values in template'
When run bash -c "grep '@sed@' '$SCRIPT'"
The output should include '@sed@'
End

It 'substitutes CLIPROXY_API_KEY in config template'
When run bash -c "grep '__CLIPROXY_API_KEY__' '$SCRIPT'"
The output should include 'CLIPROXY_API_KEY'
End

It 'substitutes TELEGRAM_TOKEN in env template'
When run bash -c "grep '__TELEGRAM_TOKEN__' '$SCRIPT'"
The output should include 'TELEGRAM_TOKEN'
End

It 'substitutes GATEWAY_TOKEN in env template'
When run bash -c "grep '__GATEWAY_TOKEN__' '$SCRIPT'"
The output should include 'GATEWAY_TOKEN'
End

It 'substitutes WHATSAPP_ALLOW_FROM in env template'
When run bash -c "grep '__WHATSAPP_ALLOW_FROM__' '$SCRIPT'"
The output should include 'WHATSAPP_ALLOW_FROM'
End

It 'substitutes Vercel credentials in env template'
When run bash -c "grep -E '__VERCEL_(TOKEN|TEAM_ID)__' '$SCRIPT'"
The output should include 'VERCEL_TOKEN'
The output should include 'VERCEL_TEAM_ID'
End

It 'creates state directory'
When run bash -c "grep 'mkdir -p' '$SCRIPT'"
The output should include 'STATE_DIR'
End
End

Describe 'declarative model routing'
It 'uses the Flash, Gemma, GLM, free fallback convention'
When run bash -c "sed -n '1,20p' '$PWD/config/hermes/config.template.yaml'"
The output should include 'default: deepseek-v4-flash'
The output should include 'provider: cliproxy'
The output should include 'model: gemma-4-31b-it'
The output should include 'model: glm-4.7'
The output should include 'model: free'
End

It 'declares exactly three Hermes fallback models'
When run bash -c "sed -n '/^fallback_providers:/,/^[^ ]/p' '$PWD/config/hermes/config.template.yaml' | grep -c '^    model:'"
The output should equal '3'
End

It 'opts both CLIProxy config schemas into stable prompt cache keys'
When run rg -c '^    supports_prompt_cache_key: true$' "$PWD/config/hermes/config.template.yaml"
The output should equal '2'
The status should be success
End

It 'delays conversation compression until context is nearly full'
When run bash -c "sed -n '/^compression:/,/^[^ ]/p' '$PWD/config/hermes/config.template.yaml'"
The output should include 'enabled: true'
The output should include 'threshold: 0.85'
The output should not include 'threshold: 0.5'
The status should be success
End

It 'keeps prompt cache TTL above the DeepSeek implicit window'
When run bash -c "sed -n '/^prompt_caching:/,/^[^ ]/p' '$PWD/config/hermes/config.template.yaml'"
The output should include 'cache_ttl: 30m'
The status should be success
End

It 'does not configure OpenRouter or Mixture-of-Agents presets'
When run bash -c "! rg -q 'openrouter|@preset/' '$PWD/config/hermes/config.template.yaml'"
The status should be success
End

It 'routes every default Mixture-of-Agents model through CLIProxy'
When run bash -c "sed -n '/^moa:/,/^credential_pool_strategies:/p' '$PWD/config/hermes/config.template.yaml' | awk '/provider: / && \$NF != \"cliproxy\" {exit 1}'"
The status should be success
End

It 'hydrates the default Mixture-of-Agents models from the canonical model list'
When run bash -c "sed -n '/^moa:/,/^credential_pool_strategies:/p' '$PWD/config/hermes/config.template.yaml'"
The output should include 'provider: cliproxy'
The output should include 'model: deepseek-v4-flash'
The output should include 'model: minimax-m3'
The output should not include 'opus'
End
End

Describe 'execution'
It 'reports config generation'
When run bash -c "grep 'Generated hermes' '$SCRIPT'"
The output should include 'Generated hermes'
End
End

End
