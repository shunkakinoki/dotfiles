#!/usr/bin/env bash
# Sync moshi-hook generated files into tracked dotfiles.
# Runs `moshi-hook install` in an isolated home to ensure all agents are current,
# then copies the generated hooks back into the repo. TypeScript helpers use a
# placeholder that Home Manager replaces with the Nix-store binary path.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
GENERATED_HOME="$(mktemp -d)"
trap 'rm -rf "$GENERATED_HOME"' EXIT

seed_json_config() {
  local source="$1"
  local destination="$GENERATED_HOME/$2"
  mkdir -p "$(dirname "$destination")"
  jq '
    def is_moshi_command:
      type == "object"
      and ((.command? // "") | type == "string")
      and (
        ((.command // "") | contains("moshi-hook"))
        or ((.command // "") | contains("@moshiHook@"))
      );
    walk(
      if type == "array" then
        map(select(is_moshi_command | not))
        | map(
            select(
              (
                type == "object"
                and has("hooks")
                and ((.hooks | length) == 0)
              )
              | not
            )
          )
      else
        .
      end
    )
  ' "$source" >"$destination"
}

normalize_helper_binary() {
  local file="$1"
  sed -E 's|^const helperBinary = .*$|const helperBinary = "@moshiHook@";|' \
    "$file" >"$file.tmp"
  mv -f "$file.tmp" "$file"
}

normalize_json_hooks() {
  local file="$1"
  sed -E \
    -e "s|'[^']*/moshi-hook'|@moshiHook@|g" \
    -e 's/\\u003e/>/g' \
    -e 's/\\u003c/</g' \
    -e 's/\\u0026/\&/g' \
    "$file" >"$file.tmp"
  mv -f "$file.tmp" "$file"
}

# Preserve non-Moshi hooks while letting the current generator replace its own
# entries. Generated TypeScript plugins are rebuilt from scratch below.
seed_json_config "$REPO_ROOT/config/claude/settings.json" ".claude/settings.json"
seed_json_config "$REPO_ROOT/config/codex/hooks.json" ".codex/hooks.json"
seed_json_config "$REPO_ROOT/config/cursor/hooks.json" ".cursor/hooks.json"
seed_json_config "$REPO_ROOT/config/gemini/settings.json" ".gemini/settings.json"

echo "Installing latest moshi-hook configs..."
HOME="$GENERATED_HOME" moshi-hook install \
  --target claude \
  --target codex \
  --target opencode \
  --target gemini \
  --target cursor \
  --target grok \
  --target omp \
  --target pi

echo "Copying generated TypeScript plugins..."
cp -f "$GENERATED_HOME/.omp/agent/extensions/moshi-hooks.ts" "$REPO_ROOT/config/omp/moshi-hooks.ts"
cp -f "$GENERATED_HOME/.pi/agent/extensions/moshi-hooks.ts" "$REPO_ROOT/config/pi/moshi-hooks.ts"
cp -f "$GENERATED_HOME/.config/opencode/plugins/moshi-hooks.ts" "$REPO_ROOT/config/opencode/moshi-hooks.ts"
normalize_helper_binary "$REPO_ROOT/config/omp/moshi-hooks.ts"
normalize_helper_binary "$REPO_ROOT/config/pi/moshi-hooks.ts"
normalize_helper_binary "$REPO_ROOT/config/opencode/moshi-hooks.ts"

echo "Copying generated JSON hooks..."
cp -f "$GENERATED_HOME/.claude/settings.json" "$REPO_ROOT/config/claude/settings.json"
cp -f "$GENERATED_HOME/.codex/hooks.json" "$REPO_ROOT/config/codex/hooks.json"
cp -f "$GENERATED_HOME/.cursor/hooks.json" "$REPO_ROOT/config/cursor/hooks.json"
cp -f "$GENERATED_HOME/.gemini/settings.json" "$REPO_ROOT/config/gemini/settings.json"
normalize_json_hooks "$REPO_ROOT/config/claude/settings.json"
normalize_json_hooks "$REPO_ROOT/config/codex/hooks.json"
normalize_json_hooks "$REPO_ROOT/config/cursor/hooks.json"
normalize_json_hooks "$REPO_ROOT/config/gemini/settings.json"
jq -s '
  def without_moshi:
    .hooks |= with_entries(
      .value |= [
        .[]
        | .hooks |= [
            .[]
            | select(
                (
                  ((.command // "") | contains("moshi-hook"))
                  or ((.command // "") | contains("@moshiHook@"))
                )
                | not
              )
          ]
        | select((.hooks | length) > 0)
      ]
      | select((.value | length) > 0)
    );
  (.[0] | without_moshi) as $custom
  | .[1] as $moshi
  | (($custom.hooks | keys) + ($moshi.hooks | keys) | unique) as $events
  | {
      hooks: reduce $events[] as $event (
        {};
        .[$event] = (($custom.hooks[$event] // []) + ($moshi.hooks[$event] // []))
      )
    }
' \
  "$REPO_ROOT/config/grok/plugin/hooks/hooks.json" \
  "$GENERATED_HOME/.grok/hooks/moshi-hooks.json" \
  >"$GENERATED_HOME/moshi-grok-merged.json"
mv -f "$GENERATED_HOME/moshi-grok-merged.json" "$REPO_ROOT/config/grok/plugin/hooks/hooks.json"
normalize_json_hooks "$REPO_ROOT/config/grok/plugin/hooks/hooks.json"

echo "Formatting..."
nix fmt -- \
  "$REPO_ROOT/config/omp/moshi-hooks.ts" \
  "$REPO_ROOT/config/pi/moshi-hooks.ts" \
  "$REPO_ROOT/config/opencode/moshi-hooks.ts" \
  "$REPO_ROOT/config/claude/settings.json" \
  "$REPO_ROOT/config/codex/hooks.json" \
  "$REPO_ROOT/config/cursor/hooks.json" \
  "$REPO_ROOT/config/gemini/settings.json" \
  "$REPO_ROOT/config/grok/plugin/hooks/hooks.json"

echo "Review changes and commit if needed"
