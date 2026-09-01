#!/usr/bin/env bash
# Regenerate every checked-in hook artifact.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
GENERATED_ROOT="${GENERATED_ROOT:-$REPO_ROOT/generated/hooks}"

copy_template() {
  local source="$1"
  local destination="$2"

  mkdir -p "$(dirname "$destination")"
  cp -f "$source" "$destination"
}

echo "Rendering native Traces hook adapters..."
copy_template \
  "$REPO_ROOT/config/openclaw/hooks/traces/HOOK.md.tpl" \
  "$GENERATED_ROOT/traces/openclaw/HOOK.md"
copy_template \
  "$REPO_ROOT/config/openclaw/hooks/traces/handler.js.tpl" \
  "$GENERATED_ROOT/traces/openclaw/handler.js"
copy_template \
  "$REPO_ROOT/config/hermes/plugins/traces/plugin.yaml.tpl" \
  "$GENERATED_ROOT/traces/hermes/plugin.yaml"
copy_template \
  "$REPO_ROOT/config/hermes/plugins/traces/__init__.py.tpl" \
  "$GENERATED_ROOT/traces/hermes/__init__.py"

if ! command -v moshi-hook >/dev/null 2>&1; then
  echo "error: moshi-hook is required; install the repo-managed package before make generate" >&2
  exit 1
fi

echo "Regenerating Moshi hook adapters..."
GENERATED_ROOT="$GENERATED_ROOT/moshi" "$SCRIPT_DIR/update-moshi-hooks.sh"

echo "Generated hook artifacts under $GENERATED_ROOT"
