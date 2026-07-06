#!/usr/bin/env bash
# Sync moshi-hook generated files into tracked dotfiles.
# Runs `moshi-hook install` to ensure all agents are current,
# then copies the generated TypeScript plugins back into the repo.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "Installing latest moshi-hook configs..."
moshi-hook install

echo "Copying generated TypeScript plugins..."
cp ~/.omp/agent/hooks/post/moshi-hooks.ts "$REPO_ROOT/config/omp/moshi-hooks.ts"
cp ~/.pi/agent/extensions/moshi-hooks.ts "$REPO_ROOT/config/pi/moshi-hooks.ts"
cp ~/.config/opencode/plugins/moshi-hooks.ts "$REPO_ROOT/config/opencode/moshi-hooks.ts"

echo "Copying generated JSON hooks..."
cp ~/.claude/settings.json "$REPO_ROOT/config/claude/settings.json"
cp ~/.codex/hooks.json "$REPO_ROOT/config/codex/hooks.json"
cp ~/.cursor/hooks.json "$REPO_ROOT/config/cursor/hooks.json"
cp ~/.gemini/settings.json "$REPO_ROOT/config/gemini/settings.json"
cp ~/.grok/hooks/moshi-hooks.json /tmp/moshi-grok-hooks.json
jq -s '.[0].hooks * .[1].hooks | {hooks: .}' \
  "$REPO_ROOT/config/grok/plugin/hooks/hooks.json" \
  /tmp/moshi-grok-hooks.json >/tmp/moshi-grok-merged.json
mv /tmp/moshi-grok-merged.json "$REPO_ROOT/config/grok/plugin/hooks/hooks.json"

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
