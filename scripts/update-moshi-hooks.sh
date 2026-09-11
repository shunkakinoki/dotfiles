#!/usr/bin/env bash
# shellcheck disable=SC2016 # The generated hook command must contain literal $HOME.
# Sync moshi-hook generated files into tracked dotfiles.
# Runs `moshi-hook install` to ensure all agents are current,
# then copies the generated TypeScript plugins back into the repo.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
GENERATED_ROOT="${GENERATED_ROOT:-$REPO_ROOT/generated/hooks/moshi}"

normalize_dcg_hooks() {
  local hook_config tmp_file

  for hook_config in "$@"; do
    if [[ ! -f $hook_config ]]; then
      echo "error: hook config not found: $hook_config" >&2
      return 1
    fi

    tmp_file="$(mktemp "${hook_config}.tmp.XXXXXX")"
    if ! sed \
      -e 's|"command": "dcg"|"command": "$HOME/dotfiles/config/shared/hooks/dcg-guard.sh"|g' \
      -e 's|"command": "[^"[:space:]]*/dcg"|"command": "$HOME/dotfiles/config/shared/hooks/dcg-guard.sh"|g' \
      -e 's|"command": "command -v dcg >/dev/null 2>&1 && dcg"|"command": "$HOME/dotfiles/config/shared/hooks/dcg-guard.sh"|g' \
      -e 's|"command": "command -v dcg \\u003e/dev/null 2\\u003e\\u00261 \\u0026\\u0026 dcg"|"command": "$HOME/dotfiles/config/shared/hooks/dcg-guard.sh"|g' \
      "$hook_config" >"$tmp_file"; then
      rm -f "$tmp_file"
      return 1
    fi

    if ! jq empty "$tmp_file"; then
      echo "error: dcg hook normalization produced invalid JSON: $hook_config" >&2
      rm -f "$tmp_file"
      return 1
    fi

    if jq -e '
      .. | objects | .command? // empty
      | select(
          . == "command -v dcg >/dev/null 2>&1 && dcg"
          or test("(^|/)dcg$")
        )
    ' "$tmp_file" >/dev/null; then
      echo "error: unguarded dcg hook remains in $hook_config" >&2
      rm -f "$tmp_file"
      return 1
    fi
    mv -f "$tmp_file" "$hook_config"
  done
}

install_orchestration_hooks() {
  local harness rendered hook_config tmp_file
  if ! command -v orchestration >/dev/null 2>&1; then
    echo "error: orchestration CLI is required to render supplemental hooks" >&2
    return 1
  fi
  for harness in claude codex; do
    if [[ $harness == claude ]]; then
      hook_config="$GENERATED_ROOT/claude/settings.json"
    else
      hook_config="$GENERATED_ROOT/codex/hooks.json"
    fi
    rendered="$(orchestration hooks render --harness "$harness")"
    tmp_file="$(mktemp "${hook_config}.tmp.XXXXXX")"
    jq -s '.[0] * {hooks: ((.[0].hooks // {}) * (.[1].hooks // {}))}' \
      "$hook_config" <(printf '%s\n' "$rendered") >"$tmp_file"
    mv -f "$tmp_file" "$hook_config"
  done
  rendered="$(orchestration hooks render --harness opencode)"
  hook_config="$REPO_ROOT/config/opencode/hooks.json"
  tmp_file="$(mktemp "${hook_config}.tmp.XXXXXX")"
  jq -s '.[0] * {hooks: ((.[0].hooks // {}) * (.[1].hooks // {}))}' \
    "$hook_config" <(printf '%s\n' "$rendered") >"$tmp_file"
  mv -f "$tmp_file" "$hook_config"
}

if [[ ${1:-} == "--normalize-only" ]]; then
  shift
  if (($# == 0)); then
    echo "error: --normalize-only requires at least one hook config" >&2
    exit 1
  fi
  normalize_dcg_hooks "$@"
  exit 0
fi

if (($# != 0)); then
  echo "usage: $0 [--normalize-only HOOK_CONFIG ...]" >&2
  exit 1
fi

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
cp ~/.cursor/hooks.json "$GENERATED_ROOT/cursor/hooks.json"
cp ~/.gemini/settings.json "$GENERATED_ROOT/gemini/settings.json"
cp ~/.grok/hooks/moshi-hooks.json /tmp/moshi-grok-hooks.json
jq -s '.[0].hooks * .[1].hooks | {hooks: .}' \
  "$GENERATED_ROOT/grok/plugin/hooks/hooks.json" \
  /tmp/moshi-grok-hooks.json >/tmp/moshi-grok-merged.json
mv /tmp/moshi-grok-merged.json "$GENERATED_ROOT/grok/plugin/hooks/hooks.json"

echo "Rendering orchestration supplemental hooks..."
install_orchestration_hooks

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

# dcg's installer may emit a resolved path, a bare invocation, or a conditional
# lookup. Route all three through the tracked fail-closed wrapper after the
# portability pass so missing installations cannot degrade shell execution to
# an unguarded, non-blocking hook failure.
normalize_dcg_hooks \
  "$GENERATED_ROOT/claude/settings.json" \
  "$GENERATED_ROOT/codex/hooks.json" \
  "$GENERATED_ROOT/cursor/hooks.json" \
  "$GENERATED_ROOT/gemini/settings.json" \
  "$GENERATED_ROOT/grok/plugin/hooks/hooks.json"

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
