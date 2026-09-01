#!/usr/bin/env bash
# shellcheck disable=SC2329

Describe 'config/openclaw/hydrate.sh'
SCRIPT="$PWD/config/openclaw/hydrate.sh"

template_uses_cliproxy_flash_default() {
  jq -e '
    .agents.defaults.model == {
      "primary": "openai/gpt-5.6-luna",
      "fallbacks": [
        "cliproxy/deepseek-v4-flash",
        "cliproxy/free"
      ]
    } and
    (.models.providers.cliproxy.models | any(.id == "deepseek-v4-pro")) and
    (.models.providers.cliproxy.models | any(.id == "deepseek-v4-flash")) and
    (.models.providers.cliproxy.models | any(.id == "free")) and
    (.agents.defaults.model.fallbacks[-1] == "cliproxy/free") and
    (.models.providers.cliproxy.models | all(
      if (.id == "deepseek-v4-pro" or .id == "deepseek-v4-flash")
      then .compat.supportsPromptCacheKey == true
      else .compat.supportsPromptCacheKey? != true
      end
    ))
  ' "$PWD/config/openclaw/openclaw.template.json" >/dev/null
}

template_disables_groups() {
  jq -e '
    (.bindings? == null) and
    (.broadcast? == null) and
    (.channels.telegram.groups? == null) and
    (.channels.telegram.groupPolicy == "disabled") and
    (.channels.whatsapp.groups? == null) and
    (.channels.whatsapp.groupPolicy == "disabled") and
    (.channels.whatsapp.ackReaction.group? == null) and
    (.messages.ackReactionScope? == null) and
    (.hooks.mappings | all(
      (.deliver? == null) and (.channel? == null) and (.to? == null)
    ))
  ' "$PWD/config/openclaw/openclaw.template.json" >/dev/null
}

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
    -e 's|@git@|git|g' \
    -e 's|@tracesHookManifest@|'"$PWD"'/config/openclaw/hooks/traces/HOOK.md|g' \
    -e 's|@tracesHookHandler@|'"$PWD"'/config/openclaw/hooks/traces/handler.js|g' \
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

It 'installs the traces hook pack as a directory with HOOK.md and a JS handler'
When run bash -c 'HOME="'"$TEMP_HOME"'" OPENCLAW_CONFIG_PATH="'"$TEMP_HOME"'/generated-openclaw.json" bash "'"$PREPROCESSED_SCRIPT"'" >/dev/null 2>&1; ls "'"$TEMP_HOME"'/.openclaw/hooks/traces"'
The status should be success
The output should include 'HOOK.md'
The output should include 'handler.js'
End

It 'initialises the workspace git repository traces publishes from'
When run bash -c 'HOME="'"$TEMP_HOME"'" OPENCLAW_CONFIG_PATH="'"$TEMP_HOME"'/generated-openclaw.json" bash "'"$PREPROCESSED_SCRIPT"'" >/dev/null 2>&1; test -d "'"$TEMP_HOME"'/.openclaw/workspace/.git" && echo repo'
The status should be success
The output should include 'repo'
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
    -e 's|@git@|git|g' \
    -e 's|@tracesHookManifest@|'"$PWD"'/config/openclaw/hooks/traces/HOOK.md|g' \
    -e 's|@tracesHookHandler@|'"$PWD"'/config/openclaw/hooks/traces/handler.js|g' \
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

Describe 'declarative template'
It 'uses CLIProxy DeepSeek V4 Flash with resilient fallbacks'
When call template_uses_cliproxy_flash_default
The status should be success
End

It 'removes group routing and explicitly disables group messages'
When call template_disables_groups
The status should be success
End

It 'contains no configured group identifiers'
When run bash -c "! rg -q '@g\\.us|\"kind\": \"group\"' '$PWD/config/openclaw/openclaw.template.json'"
The status should be success
End

It 'keeps the compiled wiki digest out of the cached system prefix'
When run bash -c "jq -e '.plugins.entries[\"memory-wiki\"].config.context.includeCompiledDigestPrompt == false' '$PWD/config/openclaw/openclaw.tpl.json' '$PWD/config/openclaw/openclaw.template.json' >/dev/null"
The status should be success
End

It 'reuses one GitHub hook session per repository'
When run bash -c "jq -r '.hooks.mappings[] | select(.match.path == \"github\") | .sessionKey' '$PWD/config/openclaw/openclaw.tpl.json' '$PWD/config/openclaw/openclaw.template.json'"
The output should include 'hook:github:{{repository.full_name}}'
The output should not include '{{delivery}}'
The status should be success
End

It 'configures ACP with a default agent and enables the acpx backend'
When run bash -c "jq -e '.acp.enabled == true and .acp.backend == \"acpx\" and .acp.defaultAgent == \"codex\" and .plugins.entries.acpx.enabled == true' '$PWD/config/openclaw/openclaw.tpl.json' '$PWD/config/openclaw/openclaw.template.json' >/dev/null"
The status should be success
End

It 'caps the skills catalog injected above the cache boundary'
When run bash -c "jq -c '.skills.limits' '$PWD/config/openclaw/openclaw.tpl.json' '$PWD/config/openclaw/openclaw.template.json'"
The output should include '"maxSkillsInPrompt":20'
The output should include '"maxSkillsPromptChars":4000'
The status should be success
End
End

Describe 'execution'
It 'generates config without starting gateway'
When run bash -c "grep 'Generated openclaw gateway config' '$SCRIPT'"
The output should include 'Generated openclaw gateway config'
End
End

End
