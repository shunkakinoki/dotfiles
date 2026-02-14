#!/usr/bin/env bash
# llm-update.sh — Propagate models.json into tool configs via template substitution.
# Template files (.tpl.*) contain __PLACEHOLDER__ tokens that get sed-replaced
# with concrete model IDs, display names, and nondot variants from models.json.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODELS="$ROOT/models.json"

[[ -f "$MODELS" ]] || { echo "ERROR: models.json not found" >&2; exit 1; }

# jq function: derive display name from a model ID
# claude-opus-4.6 → "Claude Opus 4.6", claude-sonnet-4.5-20250929 → "Claude Sonnet 4.5"
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
      elif . == "glm"    then "GLM"
      elif test("^[0-9]") then .
      else (.[0:1] | ascii_upcase) + .[1:] end) |
  join(" ");'

# Build sed args from models.json
# Order: PRETTY, NONDOT, then base — longer patterns must be replaced first
sed_args=()
while IFS=$'\t' read -r key value pretty nondot; do
  placeholder="__$(echo "$key" | tr 'a-z-' 'A-Z_')__"
  sed_args+=(-e "s|${placeholder%__}_PRETTY__|${pretty}|g")
  sed_args+=(-e "s|${placeholder%__}_NONDOT__|${nondot}|g")
  sed_args+=(-e "s|${placeholder}|${value}|g")
done < <(jq -r "$JQ_PRETTY"'
  to_entries[] |
  [.key, .value, (.value | pretty), (.value | gsub("\\.";"-"))] |
  @tsv' "$MODELS")

# Template → output pairs
declare -A TEMPLATES=(
  [config/openclaw/openclaw.tpl.json]=config/openclaw/openclaw.template.json
  [config/opencode/opencode.tpl.jsonc]=config/opencode/opencode.jsonc
  [config/llm/extra-openai-models.tpl.yaml]=config/llm/extra-openai-models.yaml
  [config/ccs/agy.settings.tpl.json]=config/ccs/agy.settings.template.json
  [config/ccs/codex.settings.tpl.json]=config/ccs/codex.settings.template.json
  [config/ccs/gemini.settings.tpl.json]=config/ccs/gemini.settings.template.json
  [config/ccs/glm.settings.tpl.json]=config/ccs/glm.settings.template.json
  [config/codex/config.tpl.toml]=config/codex/config.toml
  [config/cliproxyapi/config.tpl.yaml]=config/cliproxyapi/config.template.yaml
)

echo "Updating tool configs from $MODELS ..."
echo

for src in "${!TEMPLATES[@]}"; do
  dst="${TEMPLATES[$src]}"
  [[ -f "$ROOT/$src" ]] || { echo "SKIP: $src"; continue; }
  sed "${sed_args[@]}" "$ROOT/$src" > "$ROOT/$dst"
  echo "OK: $dst"
done

echo
echo "All configs updated."
