#!/usr/bin/env bash
# Sync moshi-hook generated files into tracked dotfiles.
# Runs `moshi-hook install` to ensure all agents are current,
# then copies the generated TypeScript plugins back into the repo.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
GENERATED_ROOT="${GENERATED_ROOT:-$REPO_ROOT/generated/hooks/moshi}"
CODEX_HERDR_MARKER='bun __DOTFILES_HERDR_SOURCE_CHECKOUT__/scripts/herdr-lane.ts hook'

normalize_codex_hooks() {
  local hooks_json="$1"
  local hooks_tmp
  hooks_tmp="$(mktemp "${hooks_json}.tmp.XXXXXX")"

  if jq \
    --arg marker "$CODEX_HERDR_MARKER" \
    '
      def owned_herdr_command:
        type == "string" and
          (test("^bun /[^ ]+/scripts/herdr-lane\\.ts hook$") or
           test("^bun \\u0027[^\\u0027]+/scripts/herdr-lane\\.ts\\u0027 hook$"));

      def ensure_event($event; $entry):
        .hooks[$event] = (((.hooks[$event] // [])
          | map(.hooks |= map(
              if (.command? | owned_herdr_command) then
                .command = $marker
              else
                .
              end
            ))) as $entries
          | if any($entries[]?.hooks[]?.command?; . == $marker) then
              $entries
            else
              $entries + [$entry]
            end);
      ensure_event("SessionStart"; {
        hooks: [{ command: $marker, type: "command" }],
        matcher: "startup|resume"
      })
      | ensure_event("UserPromptSubmit"; {
        hooks: [{ command: $marker, type: "command" }]
      })
    ' "$hooks_json" >"$hooks_tmp"; then
    chmod 644 "$hooks_tmp"
    mv -f "$hooks_tmp" "$hooks_json"
  else
    rm -f "$hooks_tmp"
    return 1
  fi
}

echo "Installing latest moshi-hook configs..."
moshi-hook install

echo "Copying generated TypeScript plugins..."
mkdir -p \
  "$GENERATED_ROOT/omp" \
  "$GENERATED_ROOT/pi" \
  "$GENERATED_ROOT/opencode" \
  "$GENERATED_ROOT/claude" \
  "$GENERATED_ROOT/codex" \
  "$GENERATED_ROOT/cursor" \
  "$GENERATED_ROOT/gemini" \
  "$GENERATED_ROOT/grok/plugin/hooks"
cp ~/.omp/agent/extensions/moshi-hooks.ts "$GENERATED_ROOT/omp/moshi-hooks.ts"
cp ~/.pi/agent/extensions/moshi-hooks.ts "$GENERATED_ROOT/pi/moshi-hooks.ts"
cp ~/.config/opencode/plugins/moshi-hooks.ts "$GENERATED_ROOT/opencode/moshi-hooks.ts"

echo "Copying generated JSON hooks..."
cp ~/.claude/settings.json "$GENERATED_ROOT/claude/settings.json"
cp ~/.codex/hooks.json "$GENERATED_ROOT/codex/hooks.json"
normalize_codex_hooks "$GENERATED_ROOT/codex/hooks.json"
cp ~/.cursor/hooks.json "$GENERATED_ROOT/cursor/hooks.json"
cp ~/.gemini/settings.json "$GENERATED_ROOT/gemini/settings.json"
cp ~/.grok/hooks/moshi-hooks.json /tmp/moshi-grok-hooks.json
jq -s '.[0].hooks * .[1].hooks | {hooks: .}' \
  "$GENERATED_ROOT/grok/plugin/hooks/hooks.json" \
  /tmp/moshi-grok-hooks.json >/tmp/moshi-grok-merged.json
mv /tmp/moshi-grok-merged.json "$GENERATED_ROOT/grok/plugin/hooks/hooks.json"

# Generated files must remain portable and must not capture a machine-local
# home directory. Moshi quotes absolute binaries in hook commands and embeds
# the resolved helper path in TypeScript adapters, so normalize the user-local
# bin prefix before copying these files into Git.
for generated_file in \
  "$GENERATED_ROOT/omp/moshi-hooks.ts" \
  "$GENERATED_ROOT/pi/moshi-hooks.ts" \
  "$GENERATED_ROOT/opencode/moshi-hooks.ts" \
  "$GENERATED_ROOT/claude/settings.json" \
  "$GENERATED_ROOT/codex/hooks.json" \
  "$GENERATED_ROOT/cursor/hooks.json" \
  "$GENERATED_ROOT/gemini/settings.json" \
  "$GENERATED_ROOT/grok/plugin/hooks/hooks.json"; do
  sed \
    -e "s|'${HOME}/.local/bin/\([^']*\)'|\1|g" \
    -e "s|${HOME}/.local/bin/||g" \
    "$generated_file" >"$generated_file.tmp"
  mv -f "$generated_file.tmp" "$generated_file"
done

echo "Formatting..."
nix fmt -- \
  "$GENERATED_ROOT/omp/moshi-hooks.ts" \
  "$GENERATED_ROOT/pi/moshi-hooks.ts" \
  "$GENERATED_ROOT/opencode/moshi-hooks.ts" \
  "$GENERATED_ROOT/claude/settings.json" \
  "$GENERATED_ROOT/codex/hooks.json" \
  "$GENERATED_ROOT/cursor/hooks.json" \
  "$GENERATED_ROOT/gemini/settings.json" \
  "$GENERATED_ROOT/grok/plugin/hooks/hooks.json"

echo "Review changes and commit if needed"
