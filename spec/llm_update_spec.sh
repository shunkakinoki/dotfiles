#!/usr/bin/env bash
# shellcheck disable=SC2329,SC2034,SC2016

Describe 'scripts/llm-update.sh'
SCRIPT="$PWD/scripts/llm-update.sh"

# Parses the generated (fixed-format) config with regexes rather than a YAML
# library: `yq` is the kislyuk jq-dialect build locally and the mikefarah build
# in CI, and no filter is valid in both.
omp_fallback_chain_tails_ok() {
  python3 - "$1" <<'PY'
import re, sys

text = open(sys.argv[1]).read()

roles = dict(re.findall(r'^  (\w+): "([^"]+)"$', re.search(
    r'^modelRoles:\n((?:  .*\n)+)', text, re.M).group(1), re.M))

chains, current = {}, None
for line in re.search(r'^  fallbackChains:\n((?:    .*\n)+)', text, re.M).group(1).splitlines():
    key = re.match(r'^    (\w+):$', line)
    if key:
        current = key.group(1)
        chains[current] = []
        continue
    item = re.match(r'^      - "([^"]+)"$', line)
    if item and current:
        chains[current].append(item.group(1))

base = lambda ref: ref.split("/", 1)[1] if "/" in ref else ref

stranded = []
for role, model in roles.items():
    chain = chains.get(role) or chains.get("default") or []
    if model in chain:
        index = chain.index(model)
    elif base(model) in [base(entry) for entry in chain]:
        index = [base(entry) for entry in chain].index(base(model))
    else:
        continue
    if index == len(chain) - 1 and base(model) != "free":
        stranded.append(f"{role} ({model}) is last in its chain")

if stranded:
    print("\n".join(stranded))
    sys.exit(1)
PY
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

Describe 'provider-specific current model aliases'
It 'keeps Antigravity aliases out of the shared model registry'
When run jq -e '.["gemini-flash"] == "gemini-3.7-flash-high" and has("antigravity-pro") == false and has("antigravity-flash") == false' models.json
The status should be success
The output should equal 'true'
End

It 'removes the superseded Codex Spark route'
When run jq -e 'has("gpt-codex") == false' models.json
The status should be success
The output should equal 'true'
End

It 'removes the retired hosted aliases'
When run jq -e 'has("glm") == false and has("gemma") == false' models.json
The status should be success
The output should equal 'true'
End

It 'removes Codex Spark from harness templates'
When run bash -c "! grep -R -E '__GPT_CODEX__|gpt-5\\.3-codex-spark' config/omp/config.tpl.yml config/openclaw/openclaw.tpl.json config/opencode/opencode.tpl.jsonc config/pi/models.tpl.json config/cliproxyapi/config.tpl.yaml"
The status should be success
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

Describe 'generated Antigravity settings'
It 'keeps the native Flash ID on the authenticated Antigravity backend'
When run jq -e '.model == "gemini-3.7-flash-high" and has("modelProvider") == false' config/antigravity/settings.tpl.json
The status should be success
The output should equal 'true'
End

It 'generates the concrete model without forcing API-key authentication'
When run jq -e '.model == "gemini-3.7-flash-high" and has("modelProvider") == false' config/antigravity/settings.json
The status should be success
The output should equal 'true'
End

It 'keeps headless Antigravity review tool allows'
When run jq -e '.permissions.allow | (index("read_file(*)") != null) and (index("command(pwd)") != null) and (index("command(wc)") != null) and (index("command(ls)") != null) and (index("command(cat)") != null) and (index("command(head)") != null) and (index("command(tail)") != null) and (index("command(stat)") != null) and (index("command(file)") != null) and (index("command(git)") != null)' config/antigravity/settings.tpl.json
The status should be success
The output should equal 'true'
End
End

Describe 'generated Factory settings'
It 'pins Droid to its built-in DeepSeek Flash model and keeps CLIProxy customs'
When run jq -e '.sessionDefaultSettings.model == "__DEEPSEEK_FLASH_0731__" and (.customModels | length) == 2 and any(.customModels[]; .id == "custom:__DEEPSEEK_FLASH__-0" and .baseUrl == "https://cliproxy.shunkakinoki.com/v1") and any(.customModels[]; .id == "custom:free-1" and .model == "free" and .baseUrl == "https://cliproxy.shunkakinoki.com/v1")' config/factory/settings.tpl.json
The status should be success
The output should equal 'true'
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

It 'uses the DeepSeek Flash alias for the small model'
When run bash -c "grep '\"small_model\": \"shunkakinoki/deepseek-v4-flash\"' config/opencode/opencode.jsonc"
The output should include 'shunkakinoki/deepseek-v4-flash'
End

It 'pins the audited OpenCode runtime fallback plugin release'
When run bash -c "grep -q '\"opencode-runtime-fallback@0.2.3\"' config/opencode/opencode.jsonc"
The status should be success
End

It 'generates the Flash OpenCode fallback convention'
When run bash -c "jq -e '.model == null and .retry_on_errors == [401,404,429,500,502,503,504] and .retryable_error_patterns == [\"unknown provider for model\"] and .max_fallback_attempts == 5 and .fallback_models == [\"shunkakinoki/free\"]' config/opencode/opencode-fallback.jsonc >/dev/null"
The status should be success
End

It 'generates the CLIProxyAPI DeepSeek models'
When run bash -c "sed -n '/\"cliproxyapi\"/,/\"lmstudio\"/p' config/opencode/opencode.jsonc | grep -q 'deepseek-v4-flash' && sed -n '/\"cliproxyapi\"/,/\"lmstudio\"/p' config/opencode/opencode.jsonc | grep -q 'deepseek-v4-pro'"
The status should be success
End

It 'generates the OMP free default role'
When run bash -c "grep 'default: \"cliproxyapi/free\"' config/omp/config.yml"
The output should include 'cliproxyapi/free'
End

It 'routes every OMP role through remote CLIProxyAPI'
When run bash -c "sed -n '/^modelRoles:/,/^# ====/p' config/omp/config.yml | grep -E '^  (default|smol|slow|vision|plan|commit|task):' | grep -v 'cliproxyapi/' || true"
The output should equal ''
End

It 'keeps CLIProxyAPI as the primary OMP model source'
When run bash -c "grep -A2 'enabledModels:' config/omp/config.yml | grep 'cliproxyapi/\*'"
The output should include 'cliproxyapi/*'
End

It 'enables OMP OpenRouter models alongside CLIProxyAPI'
When run bash -c "grep -A2 'enabledModels:' config/omp/config.yml"
The output should include 'cliproxyapi/*'
The output should include 'openrouter/*'
End

It 'uses the free-tier CLIProxy fallback chain for OMP'
When run bash -c "sed -n '/^  fallbackChains:/,/^  fallbackRevertPolicy/p' config/omp/config.yml"
The output should include 'cliproxyapi/deepseek-v4-flash'
The output should include 'cliproxyapi/free'
The output should not include 'openai-codex/'
End

It 'keeps the OMP model registry placeholder in the template'
When run bash -c "grep 'id: __DEEPSEEK_FLASH__' config/omp/models.tpl.yml"
The output should include '__DEEPSEEK_FLASH__'
End
End

Describe 'runtime model fallback'
It 'keeps Pi OpenRouter discovery enabled'
When run bash -c "jq -e '(.enabledModels | index(\"openrouter/**\") != null) and (.enabledModels | index(\"openrouter-preset/**\") == null)' config/pi/settings.json >/dev/null && jq -e '(.enabledModels | index(\"openrouter/**\") != null) and (.enabledModels | index(\"openrouter-preset/**\") == null)' config/pi/settings.tpl.json >/dev/null"
The status should be success
End

It 'points Pi cliproxyapi at remote CLIProxy'
When run bash -c "jq -e '.providers.cliproxyapi.baseUrl == \"https://cliproxy.shunkakinoki.com/v1\"' config/pi/models.json >/dev/null && jq -e '.providers.cliproxyapi.baseUrl == \"https://cliproxy.shunkakinoki.com/v1\"' config/pi/models.tpl.json >/dev/null"
The status should be success
End

It 'generates the free-tier CLIProxy Pi fallback chain'
When run bash -c "jq -e '.enabled == true and .max_fallback_attempts == 5 and .fallback_models == [\"cliproxyapi/free\"]' config/pi/fallback.json >/dev/null"
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
When call omp_fallback_chain_tails_ok config/omp/config.yml
The status should be success
End

It 'uses OMP native retry fallback chains instead of an extension'
When run bash -c "[ ! -e config/omp/fallback.ts ] && [ ! -e config/omp/fallback.json ] && grep -q 'modelFallback: true' config/omp/config.yml && grep -q 'fallbackRevertPolicy: \"cooldown-expiry\"' config/omp/config.yml"
The status should be success
End
End

Describe 'CLIProxyAPI routing'
It 'hydrates the OMP remote CLIProxyAPI catalog without the retired model'
When run bash -c "grep -q 'baseUrl: https://cliproxy.shunkakinoki.com/v1' config/omp/models.yml && grep -q 'auth: apiKey' config/omp/models.yml && grep -q 'type: openai-models-list' config/omp/models.yml && grep -q 'id: deepseek-v4-flash' config/omp/models.yml && grep -q 'id: free' config/omp/models.yml && ! grep -q 'id: gemma-4-31b-it' config/omp/models.yml && ! grep -q 'id: glm-4.7' config/omp/models.yml && ! grep -q '__DEEPSEEK_FLASH__' config/omp/models.yml"
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

It 'orders DeepSeek providers as OpenCode then Aliyun then Verboo then OpenRouter then Surplus'
When run bash -c "grep -A 2 'name: \"opencode\"' config/cliproxyapi/config.template.yaml | grep -q 'priority: 300' && grep -A 2 'name: \"aliyun\"' config/cliproxyapi/config.template.yaml | grep -q 'priority: 200' && grep -A 2 'name: \"verboo\"' config/cliproxyapi/config.template.yaml | grep -q 'priority: 150' && grep -A 2 'name: \"openrouter\"' config/cliproxyapi/config.template.yaml | grep -q 'priority: 100' && grep -A 2 'name: \"surplus\"' config/cliproxyapi/config.template.yaml | grep -q 'priority: 150'"
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

Describe 'Codex feature flags'
It 'enables remote compaction in the template and generated config'
When run bash -c "for file in config/codex/config.tpl.toml config/codex/config.toml; do sed -n '/^\[features\]$/,/^\[/p' \"\$file\" | grep -qx 'remote_compaction_v2 = true' || exit 1; done"
The status should be success
End

It 'omits feature flags removed by the current Codex CLI'
When run bash -c "removed='apply_patch_freeform apps_mcp_path_override codex_git_commit enable_fanout external_migration js_repl js_repl_tools_only plugin_hooks remote_control skill_env_var_dependency_prompt terminal_resize_reflow tool_search tool_search_always_defer_mcp_tools unavailable_dummy_tools undo workspace_owner_usage_nudge'; for file in config/codex/config.tpl.toml config/codex/config.toml; do features=\$(sed -n '/^\[features\]$/,/^\[/p' \"\$file\"); for flag in \$removed; do ! printf '%s\n' \"\$features\" | grep -q \"^\${flag}[[:space:]]*=\" || exit 1; done; done"
The status should be success
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
