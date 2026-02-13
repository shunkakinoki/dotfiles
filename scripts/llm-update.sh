#!/usr/bin/env bash
# llm-update.sh — Propagate models.json aliases into all tool configs.
# models.json is a flat alias→ID map. All structural wiring lives here.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
MODELS="$ROOT_DIR/models.json"

[[ -f "$MODELS" ]] || { echo "ERROR: models.json not found" >&2; exit 1; }

# Resolve alias → concrete model ID
resolve() { jq -r --arg a "$1" '.[$a]' "$MODELS"; }

# jq helper: derive display name from a model ID
# claude-opus-4.6 → "Claude Opus 4.6", claude-sonnet-4-5-20250929 → "Claude Sonnet 4.5"
JQ_PRETTY='
def pretty:
  gsub("-20[0-9]{6}$";"") | gsub("-preview$";"") |
  split("-") |
  reduce .[] as $s ([];
    if ($s | test("^[0-9]+$")) and length > 0 and (last | test("^[0-9]"))
    then .[:-1] + [last + "." + $s]
    else . + [$s] end) |
  map(if   . == "claude" then "Claude"
      elif . == "gpt"    then "GPT"
      elif . == "gemini"  then "Gemini"
      elif . == "glm"    then "GLM"
      elif test("^[0-9]") then .
      else (.[0:1] | ascii_upcase) + .[1:] end) |
  join(" ");
'

# --------------------------------------------------------------------------
# OpenClaw — config/openclaw/openclaw.template.json
#   All aliases → model list, claude-opus as primary, glm as fallback
# --------------------------------------------------------------------------
update_openclaw() {
  local file="$ROOT_DIR/config/openclaw/openclaw.template.json"
  [[ -f "$file" ]] || { echo "SKIP: $file not found"; return; }

  local models_array
  models_array=$(jq "$JQ_PRETTY"'
    [to_entries[] | .key as $alias | .value as $id | {
      id: $id,
      name: ($id | pretty),
      reasoning: ($alias | IN("claude-opus","claude-opus-thinking","claude-sonnet-thinking")),
      input: ["text"],
      cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 },
      contextWindow: 200000,
      maxTokens: 32000
    }]
  ' "$MODELS")

  local primary="cliproxy/$(resolve claude-opus)"
  local fallback="cliproxy/$(resolve glm)"

  jq --argjson models "$models_array" \
     --arg primary "$primary" --arg fallback "$fallback" '
    .models.providers.cliproxy.models = $models |
    .agents.defaults.model.primary = $primary |
    .agents.defaults.model.fallbacks = [$fallback]
  ' "$file" > "$file.tmp" && mv "$file.tmp" "$file"

  echo "OK: openclaw.template.json"
}

# --------------------------------------------------------------------------
# OpenCode — config/opencode/opencode.jsonc
#   Non-thinking aliases → cliproxyapi + shunkakinoki providers
#   glm uses z-ai/ prefix on shunkakinoki
# --------------------------------------------------------------------------
update_opencode() {
  local file="$ROOT_DIR/config/opencode/opencode.jsonc"
  [[ -f "$file" ]] || { echo "SKIP: $file not found"; return; }

  # Non-thinking aliases for provider model lists
  local provider_aliases='["claude-opus","claude-sonnet","claude-haiku","gpt","gpt-codex","gemini-pro","gemini-flash","glm"]'

  local cliproxyapi_models shunkakinoki_models
  cliproxyapi_models=$(jq --argjson keys "$provider_aliases" "$JQ_PRETTY"'
    [. as $m | $keys[] | . as $alias | $m[$alias] as $id |
      { ($id): { name: (($id | pretty) + " (via local CLIProxyAPI)") } }
    ] | add
  ' "$MODELS")

  shunkakinoki_models=$(jq --argjson keys "$provider_aliases" "$JQ_PRETTY"'
    [. as $m | $keys[] | . as $alias | $m[$alias] as $id |
      (if $alias == "glm" then "z-ai/" + $id else $id end) as $key |
      { ($key): { name: (($id | pretty) + " (via shunkakinoki'\''s CLIProxy)") } }
    ] | add
  ' "$MODELS")

  local model="cliproxyapi/$(resolve glm)"
  local small_model="$model"

  # Strip JSONC: remove comment-only lines, fix trailing commas
  local stripped
  stripped=$(grep -v '^\s*//' "$file" | perl -0777 -pe 's/,(\s*[}\]])/\1/g')

  echo "$stripped" | jq --tab \
    --argjson cliproxyapi "$cliproxyapi_models" \
    --argjson shunkakinoki "$shunkakinoki_models" \
    --arg model "$model" --arg small_model "$small_model" '
    .model = $model | .small_model = $small_model |
    .provider.cliproxyapi.models = $cliproxyapi |
    .provider.shunkakinoki.models = $shunkakinoki
  ' | awk '/"write": false/ {
      indent=$0; sub(/[^ \t].*/,"",indent)
      print indent "// Disable file modification tools for review-only agent"
    } {print}' > "$file"

  echo "OK: opencode.jsonc"
}

# --------------------------------------------------------------------------
# LLM — config/llm/extra-openai-models.yaml
#   Aliases: claude-sonnet, claude-opus, claude-haiku, glm
# --------------------------------------------------------------------------
update_llm() {
  local file="$ROOT_DIR/config/llm/extra-openai-models.yaml"
  local aliases='["claude-sonnet","claude-opus","claude-haiku","glm"]'

  jq -r --argjson aliases "$aliases" "$JQ_PRETTY"'
    . as $m |
    "# Custom OpenAI-compatible models for llm",
    ($aliases[] | . as $alias | $m[$alias] as $id |
      "- model_id: \($alias)",
      "  model_name: \($id)",
      "  api_base: http://localhost:8317/v1",
      "  api_key_name: cliproxyapi"
    )
  ' "$MODELS" > "$file"

  echo "OK: extra-openai-models.yaml"
}

# --------------------------------------------------------------------------
# CCS — config/ccs/{agy,codex,gemini,glm}.settings.template.json
#   Each profile maps alias tiers to model/opus/sonnet/haiku
# --------------------------------------------------------------------------
update_ccs() {
  local ccs_dir="$ROOT_DIR/config/ccs"

  # profile | base_url | auth_token | model | opus | sonnet | haiku
  local -a profiles=(
    "agy|http://127.0.0.1:8317/api/provider/agy|__CLIPROXY_API_KEY__|claude-opus-thinking|claude-opus-thinking|claude-opus-thinking|claude-sonnet"
    "codex|http://127.0.0.1:8317/api/provider/codex|__CLIPROXY_API_KEY__|gpt-codex|gpt-codex|gpt-codex|gpt-codex"
    "gemini|http://127.0.0.1:8317/api/provider/gemini|__CLIPROXY_API_KEY__|gemini-pro|gemini-pro|gemini-pro|gemini-flash"
    "glm|https://api.z.ai/api/anthropic|__ZAI_API_KEY__|glm|glm|glm|glm"
  )

  for entry in "${profiles[@]}"; do
    IFS='|' read -r name base_url auth_token m_alias o_alias s_alias h_alias <<< "$entry"
    local file="$ccs_dir/${name}.settings.template.json"
    [[ -f "$file" ]] || { echo "SKIP: $file not found"; continue; }

    jq -n \
      --arg base_url "$base_url" --arg auth_token "$auth_token" \
      --arg model "$(resolve "$m_alias")" --arg opus "$(resolve "$o_alias")" \
      --arg sonnet "$(resolve "$s_alias")" --arg haiku "$(resolve "$h_alias")" '
      { env: {
          ANTHROPIC_BASE_URL: $base_url, ANTHROPIC_AUTH_TOKEN: $auth_token,
          ANTHROPIC_MODEL: $model, ANTHROPIC_DEFAULT_OPUS_MODEL: $opus,
          ANTHROPIC_DEFAULT_SONNET_MODEL: $sonnet, ANTHROPIC_DEFAULT_HAIKU_MODEL: $haiku
      }}
    ' > "$file"

    echo "OK: ${name}.settings.template.json"
  done
}

# --------------------------------------------------------------------------
# Codex — config/codex/config.toml
# --------------------------------------------------------------------------
update_codex() {
  local file="$ROOT_DIR/config/codex/config.toml"
  [[ -f "$file" ]] || { echo "SKIP: $file not found"; return; }
  # Only replace the top-level model line (before any [section] header)
  local model
  model=$(resolve gpt-codex)
  awk -v m="$model" '!done && /^model = "/ { print "model = \"" m "\""; done=1; next } {print}' "$file" > "$file.tmp" && mv "$file.tmp" "$file"
  echo "OK: config.toml"
}

# --------------------------------------------------------------------------
# Cliproxyapi — config/cliproxyapi/config.template.yaml
#   OAuth alias: antigravity upstream=claude-opus-thinking, alias=claude-opus
# --------------------------------------------------------------------------
update_cliproxy() {
  local file="$ROOT_DIR/config/cliproxyapi/config.template.yaml"
  [[ -f "$file" ]] || { echo "SKIP: $file not found"; return; }

  local upstream alias
  # upstream name must use actual API model ID (hyphens for claude versions)
  upstream=$(resolve claude-opus-thinking | sed 's/\.\([0-9]\)/-\1/g')
  alias=$(resolve claude-opus)

  local block
  block="oauth-model-alias:
  antigravity:
    - name: \"${upstream}\"
      alias: \"${alias}\"
      fork: true"

  if grep -q '^oauth-model-alias:' "$file"; then
    awk -v replacement="$block" '
      /^oauth-model-alias:/ { found=1; print replacement; next }
      found && /^[^ #]/ { found=0 }
      found { next }
      { print }
    ' "$file" > "$file.tmp" && mv "$file.tmp" "$file"
  else
    printf '\n%s\n' "$block" >> "$file"
  fi

  echo "OK: config.template.yaml"
}

# --------------------------------------------------------------------------
echo "Updating tool configs from $MODELS ..."
echo
update_openclaw
update_opencode
update_llm
update_ccs
update_codex
update_cliproxy
echo
echo "All configs updated."
