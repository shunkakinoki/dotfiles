#!/usr/bin/env bash
# shellcheck disable=SC2329,SC2034,SC2016

Describe 'scripts/llm-update.sh'
SCRIPT="$PWD/scripts/llm-update.sh"

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

Describe 'models.json dependency'
It 'references models.json'
When run bash -c "grep 'models.json' '$SCRIPT'"
The output should include 'models.json'
End

It 'exits if models.json is missing'
When run bash -c "grep 'models.json not found' '$SCRIPT'"
The output should include 'ERROR'
End

It 'checks for jq before generating outputs'
When run bash -c "grep 'require_command jq' '$SCRIPT'"
The output should include 'require_command jq'
End
End

Describe 'template processing'
It 'uses sed for substitution'
When run bash -c "grep 'sed' '$SCRIPT'"
The output should include 'sed'
End

It 'defines template-to-output mappings'
When run bash -c "grep 'TEMPLATES' '$SCRIPT'"
The output should include 'TEMPLATES'
End

It 'processes .tpl. template files'
When run bash -c "grep '\.tpl\.' '$SCRIPT'"
The output should include '.tpl.'
End
End

Describe 'mapping coverage'
It 'includes aichat config in template mappings'
When run bash -c "grep 'config/aichat/config.tpl.yaml' '$SCRIPT'"
The output should include 'config/aichat/config.tpl.yaml'
End

It 'includes pi settings in template mappings'
When run bash -c "grep 'config/pi/settings.tpl.json' '$SCRIPT'"
The output should include 'config/pi/settings.tpl.json'
End

It 'includes the pi fallback chain in template mappings'
When run bash -c "grep 'config/pi/fallback.tpl.json' '$SCRIPT'"
The output should include 'config/pi/fallback.tpl.json'
End

It 'includes llm default model in template mappings'
When run bash -c "grep 'config/llm/default_model.tpl.txt' '$SCRIPT'"
The output should include 'config/llm/default_model.tpl.txt'
End

It 'includes fish wrapper templates in template mappings'
When run bash -c "grep '_ocxe_function.tpl.fish' '$SCRIPT' && grep '_pixe_function.tpl.fish' '$SCRIPT' && grep '_pixel_function.tpl.fish' '$SCRIPT'"
The output should include '_ocxe_function.tpl.fish'
The output should include '_pixe_function.tpl.fish'
The output should include '_pixel_function.tpl.fish'
End

It 'includes OMP model registry in template mappings'
When run bash -c "grep 'config/omp/models.tpl.yml' '$SCRIPT'"
The output should include 'config/omp/models.tpl.yml'
End
End

Describe 'generated fish wrapper outputs'
Parameters:dynamic
for file in $(git ls-files 'home-manager/programs/fish/functions/*.tpl.fish'); do
  output_file=${file/.tpl/}
  %data "$file" "$output_file"
done
End

It 'has a generated fish wrapper sibling: $2'
The path "$2" should be exist
End

It 'keeps generated fish wrappers non-empty: $2'
When run bash -c "[ -s '$2' ]"
The status should be success
End

It 'resolves placeholders in generated fish wrappers: $2'
When run bash -c "! grep -Eq '__[A-Z0-9_]+__' '$2'"
The status should be success
End
End

Describe 'OpenCode runtime fallback'
It 'keeps DeepSeek Flash as the explicit default model'
When run bash -c "grep '\"model\": \"shunkakinoki/deepseek-v4-flash\"' config/opencode/opencode.jsonc"
The output should include 'shunkakinoki/deepseek-v4-flash'
End

It 'enables stable prompt cache keys for both CLIProxy providers'
When run bash -c "sed -n '/\"shunkakinoki\"/,/\"cliproxyapi\"/p' config/opencode/opencode.jsonc | grep -q '\"setCacheKey\": true' && sed -n '/\"cliproxyapi\"/,/\"lmstudio\"/p' config/opencode/opencode.jsonc | grep -q '\"setCacheKey\": true'"
The status should be success
End

It 'uses the CLIProxy provider-fallback GLM alias for the small model'
When run bash -c "grep '\"small_model\": \"shunkakinoki/glm-4.7\"' config/opencode/opencode.jsonc"
The output should include 'shunkakinoki/glm-4.7'
End

It 'pins the audited OpenCode runtime fallback plugin release'
When run bash -c "grep -q '\"opencode-runtime-fallback@0.2.3\"' config/opencode/opencode.jsonc"
The status should be success
End

It 'generates a separate OpenCode fallback chain'
When run bash -c "jq -e '.retry_on_errors == [401,404,429,500,502,503,504] and .retryable_error_patterns == [\"unknown provider for model\"] and .max_fallback_attempts == 5 and .fallback_models == [\"shunkakinoki/gemma-4-31b-it\",\"shunkakinoki/glm-4.7\",\"shunkakinoki/free\"]' config/opencode/opencode-fallback.jsonc >/dev/null"
The status should be success
End

It 'generates the CLIProxyAPI DeepSeek models'
When run bash -c "sed -n '/\"cliproxyapi\"/,/\"lmstudio\"/p' config/opencode/opencode.jsonc | grep -q 'deepseek-v4-flash' && sed -n '/\"cliproxyapi\"/,/\"lmstudio\"/p' config/opencode/opencode.jsonc | grep -q 'deepseek-v4-pro'"
The status should be success
End

It 'generates the OMP Flash default role'
When run bash -c "grep 'default: \"cliproxyapi/deepseek-v4-flash\"' config/omp/config.yml"
The output should include 'cliproxyapi/deepseek-v4-flash'
End

It 'keeps the OMP model registry placeholder in the template'
When run bash -c "grep 'id: __DEEPSEEK_FLASH__' config/omp/models.tpl.yml"
The output should include '__DEEPSEEK_FLASH__'
End
End

Describe 'runtime model fallback'
It 'generates the free-tier CLIProxy Pi fallback chain'
When run bash -c "jq -e '.enabled == true and .max_fallback_attempts == 5 and .fallback_models == [\"cliproxyapi/gemma-4-31b-it\",\"cliproxyapi/glm-4.7\",\"cliproxyapi/free\"]' config/pi/fallback.json >/dev/null"
The status should be success
End

It 'resolves every Pi fallback model against the Pi registry'
# pi.modelRegistry.find(provider, id) returns undefined for anything missing
# here, which would cool the whole chain down as "unavailable" at runtime.
When run bash -c "known=\$(jq -r '.providers | to_entries[] | .key as \$p | .value.models[] | \"\(\$p)/\(.id)\"' config/pi/models.json) && jq -r '.fallback_models[]' config/pi/fallback.json | while IFS= read -r ref; do printf '%s\n' \"\$known\" | grep -Fxq \"\$ref\" || { echo \"unresolvable: \$ref\"; exit 1; }; done"
The status should be success
End

It 'keeps the Pi policy schema within the OpenCode schema'
When run bash -c "pi=\$(jq -Sc 'keys' config/pi/fallback.json) && jq -Se --argjson pi \"\$pi\" '(keys - \$pi) == [\"timeout_seconds\"]' config/opencode/opencode-fallback.jsonc >/dev/null"
The status should be success
End

It 'omits the OpenCode-only timeout knob a Pi extension cannot honor'
When run bash -c "! grep -q 'timeout_seconds' config/pi/fallback.json && ! grep -qE '^\s+timeout_seconds' config/pi/fallback.ts"
The status should be success
End

It 'ships the Pi fallback as a single self-contained extension'
When run bash -c "grep -q 'export default function piRuntimeFallback' config/pi/fallback.ts && grep -q '\".pi/agent/extensions/fallback.ts\"' config/pi/default.nix && [ ! -e config/shared/fallback ]"
The status should be success
End

It 'never leaves an OMP role on the last entry of the chain it inherits'
# OMP resolves candidates positionally, by exact selector then by base selector
# (provider stripped), so a role matching either way at the tail gets none.
When run bash -c "yq -e '.retry.fallbackChains as \$c | .modelRoles | to_entries | all(. as \$r | ((\$c[\$r.key] // \$c.default) as \$chain | (\$chain | map(sub(\"^[^/]+/\";\"\"))) as \$bases | ((\$chain | index(\$r.value)) // (\$bases | index(\$r.value | sub(\"^[^/]+/\";\"\")))) as \$i | \$i == null or \$i < ((\$chain | length) - 1)))' config/omp/config.yml >/dev/null"
The status should be success
End

It 'uses OMP native retry fallback chains instead of an extension'
When run bash -c "[ ! -e config/omp/fallback.ts ] && [ ! -e config/omp/fallback.json ] && yq -e '.retry.modelFallback == true and .retry.fallbackRevertPolicy == \"cooldown-expiry\" and .retry.fallbackChains.default == [\"openai-codex/gpt-5.6-luna\",\"openai-codex/gpt-5.3-codex-spark\",\"openai-codex/gpt-5.6-sol\"]' config/omp/config.yml >/dev/null"
The status should be success
End
End

Describe 'CLIProxyAPI routing'
It 'hydrates the OMP local CLIProxyAPI DeepSeek Flash provider'
When run bash -c "grep -q 'baseUrl: http://127.0.0.1:8317/v1' config/omp/models.yml && grep -q 'id: deepseek-v4-flash' config/omp/models.yml && ! grep -q '__DEEPSEEK_FLASH__' config/omp/models.yml"
The status should be success
End

It 'generates the DeepSeek Go routes in CliProxy'
When run bash -c "sed -n '/name: \"opencode\"/,/name: \"openai\"/p' config/cliproxyapi/config.template.yaml | grep -q 'name: \"deepseek-v4-pro\"' && sed -n '/name: \"opencode\"/,/name: \"openai\"/p' config/cliproxyapi/config.template.yaml | grep -q 'name: \"deepseek-v4-flash\"'"
The status should be success
End

It 'routes DeepSeek presets through OpenRouter with OpenCode Go fallbacks in CliProxy'
When run bash -c "sed -n '/name: \"openrouter\"/,/name: \"z-ai\"/p' config/cliproxyapi/config.template.yaml | grep -q 'name: \"@preset/deepseek-v4-pro\"' && sed -n '/name: \"openrouter\"/,/name: \"z-ai\"/p' config/cliproxyapi/config.template.yaml | grep -q 'name: \"@preset/deepseek-v4-flash\"' && sed -n '/name: \"opencode\"/,/name: \"openai\"/p' config/cliproxyapi/config.template.yaml | grep -q 'name: \"deepseek-v4-pro\"' && sed -n '/name: \"opencode\"/,/name: \"openai\"/p' config/cliproxyapi/config.template.yaml | grep -q 'name: \"deepseek-v4-flash\"'"
The status should be success
End

It 'maps the OpenRouter free router to the canonical alias'
When run bash -c "section=\$(sed -n '/name: \"openrouter\"/,/name: \"z-ai\"/p' config/cliproxyapi/config.template.yaml); printf '%s\n' \"\$section\" | grep -q 'name: \"openrouter/free\"' && printf '%s\n' \"\$section\" | grep -q 'alias: \"free\"'"
The status should be success
End

It 'does not expose a main alias through OpenCode or CLIProxy'
When run bash -c "! grep -q '\"main\": {' config/opencode/opencode.jsonc && ! grep -q 'alias: \"main\"' config/cliproxyapi/config.template.yaml"
The status should be success
End

It 'hydrates the versioned Aliyun DeepSeek model behind the canonical alias'
When run bash -c "section=\$(sed -n '/name: \"aliyun\"/,/name: \"opencode\"/p' config/cliproxyapi/config.template.yaml); printf '%s\n' \"\$section\" | grep -q 'name: \"deepseek-v4-flash-0731\"' && printf '%s\n' \"\$section\" | grep -q 'alias: \"deepseek-v4-flash\"'"
The status should be success
End

It 'orders DeepSeek providers as OpenCode then Aliyun then OpenRouter'
When run bash -c "grep -A 2 'name: \"opencode\"' config/cliproxyapi/config.template.yaml | grep -q 'priority: 300' && grep -A 2 'name: \"aliyun\"' config/cliproxyapi/config.template.yaml | grep -q 'priority: 200' && grep -A 2 'name: \"openrouter\"' config/cliproxyapi/config.template.yaml | grep -q 'priority: 100'"
The status should be success
End

It 'only exposes selected model aliases plus the reserved free router alias'
When run bash -c "allowed=\$(jq -r '.[]' models.json); while IFS= read -r alias; do [ \"\$alias\" = free ] || printf '%s\n' \"\$allowed\" | grep -Fxq \"\$alias\" || { echo \"unexpected alias: \$alias\"; exit 1; }; done < <(sed -n 's/^[[:space:]]*alias: \"\\(.*\\)\"/\\1/p' config/cliproxyapi/config.template.yaml)"
The status should be success
End
End

Describe 'Codex subagent defaults'
It 'keeps the subagent model as a placeholder in the template'
When run bash -c "sed -n '/^\[agents\]/,/^\[/p' config/codex/config.tpl.toml | grep 'default_subagent_model'"
The output should include '__GPT_LUNA__'
End

It 'hydrates the subagent model from models.json'
When run bash -c "sed -n '/^\[agents\]/,/^\[/p' config/codex/config.toml | grep 'default_subagent_model'"
The output should include 'gpt-5.6-luna'
The output should not include '__GPT_LUNA__'
End

It 'enables the agents section'
When run bash -c "sed -n '/^\[agents\]/,/^\[/p' config/codex/config.toml | grep 'enabled'"
The output should include 'enabled = true'
End

It 'uses only the canonical per-session concurrency setting'
When run bash -c "for file in config/codex/config.tpl.toml config/codex/config.toml; do agents=\$(sed -n '/^\[agents\]/,/^\[/p' \"\$file\"); test \"\$(printf '%s\n' \"\$agents\" | grep -Ec '^(max_threads|max_concurrent_threads_per_session) = ')\" -eq 1 && printf '%s\n' \"\$agents\" | grep -qx 'max_concurrent_threads_per_session = 300' || exit 1; done"
The status should be success
End

It 'runs subagents at max reasoning effort'
When run bash -c "sed -n '/^\[agents\]/,/^\[/p' config/codex/config.toml | grep 'default_subagent_reasoning_effort'"
The output should include 'max'
End

It 'enables the max reasoning effort it defaults subagents to'
When run bash -c "grep 'enabled-reasoning-efforts' config/codex/config.toml"
The output should include 'max'
End
End

Describe 'jq pretty-printing'
It 'defines a jq pretty function for model names'
When run bash -c "grep 'def pretty' '$SCRIPT'"
The output should include 'def pretty'
End

It 'capitalizes Claude model names'
When run bash -c "grep 'Claude' '$SCRIPT'"
The output should include 'Claude'
End
End

Describe 'placeholder generation'
It 'converts keys to uppercase placeholders'
When run bash -c "grep 'placeholder=' '$SCRIPT'"
The output should include '__'
End

It 'generates PRETTY variant placeholders'
When run bash -c "grep '_PRETTY__' '$SCRIPT'"
The output should include '_PRETTY__'
End

It 'generates NONDOT variant placeholders'
When run bash -c "grep '_NONDOT__' '$SCRIPT'"
The output should include '_NONDOT__'
End

It 'supports provider-specific override placeholders'
When run bash -c "grep 'add_model_override' '$SCRIPT'"
The output should include 'add_model_override'
The output should include 'gpt-image'
The output should include 'openrouter'
The output should include 'deepseek-flash'
The output should include '0731'
End
End

Describe 'provider-specific override resolution'
setup_provider_override_fixture() {
  TEMP_ROOT=$(mktemp -d)

  mkdir -p "$TEMP_ROOT/scripts" "$TEMP_ROOT/config/cliproxyapi"
  cp -f "$SCRIPT" "$TEMP_ROOT/scripts/llm-update.sh"
  cp -f "$PWD/models.json" "$TEMP_ROOT/models.json"

  cat >"$TEMP_ROOT/config/cliproxyapi/config.tpl.yaml" <<'EOF'
openai-compatibility:
  - name: "openrouter"
    models:
      - name: "__GPT_IMAGE_OPENROUTER__"
        alias: "__GPT_IMAGE__"
EOF
}

cleanup_provider_override_fixture() {
  rm -rf "$TEMP_ROOT"
}

Before 'setup_provider_override_fixture'
After 'cleanup_provider_override_fixture'

It 'replaces provider-specific placeholders in generated configs'
When run bash -c "cd '$TEMP_ROOT' && bash scripts/llm-update.sh >/dev/null && cat config/cliproxyapi/config.template.yaml"
The output should include 'openai/gpt-5.4-image-2'
The output should include 'gpt-image-2'
The output should not include '__GPT_IMAGE_OPENROUTER__'
End
End

Describe 'failure handling'
setup_failure_fixture() {
  TEMP_ROOT=$(mktemp -d)
  MOCK_BIN=$(mktemp -d)
  TARGET="$TEMP_ROOT/home-manager/programs/fish/functions/_pixelh_function.fish"

  mkdir -p "$TEMP_ROOT/scripts" "$(dirname "$TARGET")"
  cp -f "$SCRIPT" "$TEMP_ROOT/scripts/llm-update.sh"
  cp -f "$PWD/models.json" "$TEMP_ROOT/models.json"
  cp -f "$PWD/home-manager/programs/fish/functions/_pixelh_function.tpl.fish" "$TEMP_ROOT/home-manager/programs/fish/functions/_pixelh_function.tpl.fish"
  printf 'sentinel\n' >"$TARGET"

  cat >"$MOCK_BIN/jq" <<'EOF'
#!/usr/bin/env bash
echo "mock jq failure" >&2
exit 127
EOF
  chmod +x "$MOCK_BIN/jq"

  REAL_BIN_DIRS=$(
    for cmd in bash dirname mktemp mv sed tr awk paste; do
      dirname "$(command -v "$cmd")"
    done | awk '!seen[$0]++ { printf "%s%s", sep, $0; sep=":" }'
  )
}

cleanup_failure_fixture() {
  rm -rf "$TEMP_ROOT" "$MOCK_BIN"
}

Before 'setup_failure_fixture'
After 'cleanup_failure_fixture'

It 'fails fast when jq is unavailable'
When run bash -c "PATH='$MOCK_BIN:$REAL_BIN_DIRS' bash '$TEMP_ROOT/scripts/llm-update.sh' >/dev/null 2>&1"
The status should not be success
End

It 'preserves generated outputs when jq is unavailable'
When run bash -c "PATH='$MOCK_BIN:$REAL_BIN_DIRS' bash '$TEMP_ROOT/scripts/llm-update.sh' >/dev/null 2>&1 || true; cat '$TARGET'"
The output should equal 'sentinel'
End
End

End
