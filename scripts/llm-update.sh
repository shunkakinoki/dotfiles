#!/usr/bin/env bash
# llm-update.sh — Propagate models.json into tool configs via template substitution.
# Template files (.tpl.*) contain __PLACEHOLDER__ tokens that get sed-replaced
# with concrete model IDs, display names, and nondot variants from models.json.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODELS="$ROOT/models.json"

FREE_MODELS="$ROOT/models.free.json"

[[ -f $MODELS ]] || {
  echo "ERROR: models.json not found" >&2
  exit 1
}
[[ -f $FREE_MODELS ]] || {
  echo "ERROR: models.free.json not found" >&2
  exit 1
}

require_command() {
  local cmd="$1"
  command -v "$cmd" >/dev/null 2>&1 || {
    echo "ERROR: required command '$cmd' not found" >&2
    exit 1
  }
}

require_command jq
require_command sed
require_command mktemp
require_command mv
require_command awk

add_model_override() {
  local key="$1"
  local suffix="$2"
  local value="$3"
  local placeholder
  placeholder="__$(echo "${key}-${suffix}" | tr 'a-z-' 'A-Z_')__"
  sed_args+=(-e "s|${placeholder}|${value}|g")
}

# jq function: derive display name from a model ID
# claude-opus-4.6 → "Claude Opus 4.6", claude-sonnet-4.5-20250929 → "Claude Sonnet 4.5"
# shellcheck disable=SC2016
JQ_PRETTY='def pretty:
  gsub("-20[0-9]{6}$";"") | gsub("-preview$";"") |
  split("-") |
  reduce .[] as $s ([];
    if ($s | test("^[0-9]+$")) and length > 0 and (last | test("^[0-9]"))
    then .[:-1] + [last + "." + $s]
    else . + [$s] end) |
  map(if   . == "claude" then "Claude"
      elif . == "gpt"    then "GPT"
      elif . == "gemini"  then "Gemini"
      elif test("^[0-9]") then .
      else (.[0:1] | ascii_upcase) + .[1:] end) |
  join(" ");'

# Build sed args from models.json
# Order: PRETTY, NONDOT, then base — longer patterns must be replaced first
sed_args=()
model_rows="$(
  jq -r "$JQ_PRETTY"'
    to_entries[] |
    [.key, .value, (.value | pretty), (.value | gsub("\\.";"-"))] |
    @tsv' "$MODELS"
)" || {
  echo "ERROR: failed to parse models.json" >&2
  exit 1
}

[[ -n $model_rows ]] || {
  echo "ERROR: no model rows generated from $MODELS" >&2
  exit 1
}

# Keep the shared registry canonical while deriving the CLIProxy Antigravity
# thinking tiers from its one model entry. The upstream catalog uses the
# `-low`, `-medium`, `-high`, and `-xhigh` suffixes; the family alias is an
# additional entry pointing to the high tier so T3 requests for gemini-4-neon
# remain valid.
if ! neon_model="$(jq -er '."gemini-neon" // empty' "$MODELS")" || [[ -z $neon_model ]]; then
  echo "ERROR: models.json must define a non-empty gemini-neon model" >&2
  exit 1
fi
case "$neon_model" in
  *[!A-Za-z0-9._-]*)
    echo "ERROR: gemini-neon contains unsupported characters" >&2
    exit 1
    ;;
esac

neon_aliases_file="$(mktemp)"
trap 'rm -f "$neon_aliases_file"' EXIT
neon_display="$(printf '%s\n' "${neon_model#gemini-}" | awk -F- '{ for (i = 1; i <= NF; i++) $i = toupper(substr($i, 1, 1)) substr($i, 2); OFS = " "; print }')"
neon_display="Gemini ${neon_display}"
for tier in low medium high xhigh; do
  tier_model="${neon_model}-${tier}"
  tier_alias="$tier_model"
  case "$tier" in
    low) tier_title="Low" ;;
    medium) tier_title="Medium" ;;
    high) tier_title="High" ;;
    xhigh) tier_title="XHigh" ;;
  esac
  tier_display="${neon_display} (${tier_title})"
  printf '    - name: "%s"\n      alias: "%s"\n      display-name: "%s"\n      force-mapping: true\n' \
    "$tier_model" "$tier_alias" "$tier_display" >>"$neon_aliases_file"
done
printf '    - name: "%s-high"\n      alias: "%s"\n      display-name: "%s"\n      force-mapping: true\n' \
  "$neon_model" "$neon_model" "$neon_display" >>"$neon_aliases_file"

while IFS=$'\t' read -r key value pretty nondot; do
  [[ -n $key ]] || continue
  placeholder="__$(echo "$key" | tr 'a-z-' 'A-Z_')__"
  sed_args+=(-e "s|${placeholder%__}_PRETTY__|${pretty}|g")
  sed_args+=(-e "s|${placeholder%__}_NONDOT__|${nondot}|g")
  sed_args+=(-e "s|${placeholder}|${value}|g")
done <<<"$model_rows"

# Time-limited free campaign models: key "foo" fills __FREE_FOO__.
free_rows="$(jq -r 'to_entries[] | [.key, .value] | @tsv' "$FREE_MODELS")" || {
  echo "ERROR: failed to parse models.free.json" >&2
  exit 1
}
while IFS=$'\t' read -r key value; do
  [[ -n $key ]] || continue
  sed_args+=(-e "s|__FREE_$(echo "$key" | tr 'a-z-' 'A-Z_')__|${value}|g")
done <<<"$free_rows"

# Provider-specific upstream slugs that intentionally differ from the canonical
# alias stored in models.json.
add_model_override "gpt-image" "openrouter" "openai/gpt-5.4-image-2"
add_model_override "gpt-luna" "openrouter" "openai/gpt-6-luna"
add_model_override "claude-haiku" "openrouter" "anthropic/claude-haiku-5.5"
# Ollama and NVIDIA still use their unversioned upstream IDs.
add_model_override "deepseek-flash" "unversioned" "deepseek-v4.1-flash"
# The OpenRouter account has no deepseek preset; call the public model id.
add_model_override "deepseek-flash" "openrouter" "deepseek/deepseek-v4.1-flash"
add_model_override "deepseek-flash" "0731" "deepseek-v4-flash-0731"
# OpenCode Zen has no v4.1 id; its flash model is served as deepseek-v4-flash.
add_model_override "deepseek-flash" "zen" "deepseek-v4-flash"

# Template → output pairs
declare -A TEMPLATES=(
  ["config/aichat/config.tpl.yaml"]=config/aichat/config.yaml
  ["config/antigravity/settings.tpl.json"]=config/antigravity/settings.json
  ["config/claude/settings.tpl.json"]=config/claude/settings.json
  ["config/claude/t3-pstack-models.tpl.md"]=config/claude/t3-pstack-models.md
  ["config/llm/default_model.tpl.txt"]=config/llm/default_model.txt
  ["config/openclaw/openclaw.tpl.json"]=config/openclaw/openclaw.template.json
  ["config/opencode/opencode.tpl.jsonc"]=config/opencode/opencode.jsonc
  ["config/opencode/opencode-fallback.tpl.jsonc"]=config/opencode/opencode-fallback.jsonc
  ["config/llm/extra-openai-models.tpl.yaml"]=config/llm/extra-openai-models.yaml
  ["config/codex/config.tpl.toml"]=config/codex/config.toml
  ["config/codex/profiles/cliproxy.config.tpl.toml"]=config/codex/profiles/cliproxy.config.toml
  ["config/codex/profiles/cliproxy-astra.config.tpl.toml"]=config/codex/profiles/cliproxy-astra.config.toml
  ["config/codex/profiles/cliproxy-sol.config.tpl.toml"]=config/codex/profiles/cliproxy-sol.config.toml
  ["config/codex/profiles/cliproxy-luna.config.tpl.toml"]=config/codex/profiles/cliproxy-luna.config.toml
  ["config/codex/profiles/qwen-local.config.tpl.toml"]=config/codex/profiles/qwen-local.config.toml
  ["config/cliproxyapi/config.tpl.yaml"]=config/cliproxyapi/config.template.yaml
  ["config/dsh/settings.tpl.yaml"]=config/dsh/settings.yaml
  ["config/reasonix/config.tpl.toml"]=config/reasonix/config.toml
  ["config/handy/settings_store.tpl.json"]=config/handy/settings_store.template.json
  ["config/factory/settings.tpl.json"]=config/factory/settings.json
  ["config/hermes/config.tpl.yaml"]=config/hermes/config.template.yaml
  ["config/omp/config.tpl.yml"]=config/omp/config.yml
  ["config/omp/models.tpl.yml"]=config/omp/models.yml
  ["config/pi/models.tpl.json"]=config/pi/models.json
  ["config/pi/settings.tpl.json"]=config/pi/settings.json
  ["config/pi/fallback.tpl.json"]=config/pi/fallback.json
  ["home-manager/programs/fish/functions/_coxe_function.tpl.fish"]=home-manager/programs/fish/functions/_coxe_function.fish
  ["home-manager/programs/fish/functions/_coxeh_function.tpl.fish"]=home-manager/programs/fish/functions/_coxeh_function.fish
  ["home-manager/programs/fish/functions/_coxel_function.tpl.fish"]=home-manager/programs/fish/functions/_coxel_function.fish
  ["home-manager/programs/fish/functions/_coxelh_function.tpl.fish"]=home-manager/programs/fish/functions/_coxelh_function.fish
  ["home-manager/programs/fish/functions/_ocxe_function.tpl.fish"]=home-manager/programs/fish/functions/_ocxe_function.fish
  ["home-manager/programs/fish/functions/_ocxel_function.tpl.fish"]=home-manager/programs/fish/functions/_ocxel_function.fish
  ["home-manager/programs/fish/functions/_ocxeh_function.tpl.fish"]=home-manager/programs/fish/functions/_ocxeh_function.fish
  ["home-manager/programs/fish/functions/_ocxelh_function.tpl.fish"]=home-manager/programs/fish/functions/_ocxelh_function.fish
  ["home-manager/programs/fish/functions/_pixe_function.tpl.fish"]=home-manager/programs/fish/functions/_pixe_function.fish
  ["home-manager/programs/fish/functions/_pixel_function.tpl.fish"]=home-manager/programs/fish/functions/_pixel_function.fish
  ["home-manager/programs/fish/functions/_pixelh_function.tpl.fish"]=home-manager/programs/fish/functions/_pixelh_function.fish
  ["home-manager/programs/fish/functions/_pixeh_function.tpl.fish"]=home-manager/programs/fish/functions/_pixeh_function.fish
)

echo "Updating tool configs from $MODELS ..."
echo

for src in "${!TEMPLATES[@]}"; do
  dst="${TEMPLATES[$src]}"
  [[ -f "$ROOT/$src" ]] || {
    echo "SKIP: $src"
    continue
  }

  tmp=$(mktemp "$ROOT/.llm-update.XXXXXX")
  if ! sed "${sed_args[@]}" "$ROOT/$src" >"$tmp"; then
    rm -f "$tmp"
    echo "ERROR: sed failed for $src" >&2
    exit 1
  fi
  if grep -Fq '__GEMINI_NEON_ANTIGRAVITY_ALIASES__' "$tmp"; then
    expanded_tmp="$(mktemp "$ROOT/.llm-update.XXXXXX")"
    awk -v marker='__GEMINI_NEON_ANTIGRAVITY_ALIASES__' -v block="$neon_aliases_file" '
      index($0, marker) {
        while ((getline line < block) > 0) print line
        close(block)
        next
      }
      { print }
    ' "$tmp" >"$expanded_tmp"
    mv -f "$expanded_tmp" "$tmp"
  fi
  if ! mv -f "$tmp" "$ROOT/$dst"; then
    rm -f "$tmp"
    echo "ERROR: failed to update $dst" >&2
    exit 1
  fi
  echo "OK: $dst"
done

echo
echo "All configs updated."
