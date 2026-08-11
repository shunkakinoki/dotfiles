#!/usr/bin/env bash
set -euo pipefail

OPENCODE_BIN="${1:-opencode}"
JQ_BIN="${2:-jq}"
BUN_BIN="${3:-bun}"
CONFIG_ROOT="${XDG_CONFIG_HOME:-${HOME}/.config}/opencode"

if [[ ! -x $OPENCODE_BIN ]]; then
  echo "ERROR: OpenCode executable not found: ${OPENCODE_BIN}" >&2
  exit 1
fi

if [[ ! -x $JQ_BIN ]]; then
  echo "ERROR: jq executable not found: ${JQ_BIN}" >&2
  exit 1
fi

if [[ ! -x $BUN_BIN ]]; then
  echo "ERROR: Bun executable not found: ${BUN_BIN}" >&2
  exit 1
fi

if ! effective_config="$($OPENCODE_BIN debug config)"; then
  echo "ERROR: failed to resolve effective OpenCode config" >&2
  exit 1
fi

if ! plugin_spec_lines="$({
  printf '%s\n' "$effective_config" | "$JQ_BIN" -r '
    .plugin[]? |
    select(type == "string") |
    select(
      (startswith("file://") or
       startswith("./") or
       startswith("../") or
       startswith("/") or
       startswith("-")) | not
    )
  '
})"; then
  echo "ERROR: failed to read npm plugins from effective OpenCode config" >&2
  exit 1
fi

plugin_specs=()
if [[ -n $plugin_spec_lines ]]; then
  mapfile -t plugin_specs <<<"$plugin_spec_lines"
fi

install_plugin() {
  local plugin_spec="$1"
  local package_name plugin_manifest

  case "$plugin_spec" in
  @*/*@*)
    package_name="${plugin_spec%@*}"
    ;;
  @*/*)
    package_name="$plugin_spec"
    ;;
  *@*)
    package_name="${plugin_spec%@*}"
    ;;
  *)
    package_name="$plugin_spec"
    ;;
  esac

  plugin_manifest="${CONFIG_ROOT}/node_modules/${package_name}/package.json"

  if [[ -f $plugin_manifest ]]; then
    echo "OpenCode plugin already ready: ${plugin_spec}"
    return
  fi

  "$BUN_BIN" add \
    --cwd "$CONFIG_ROOT" \
    --exact \
    --minimum-release-age 0 \
    "$plugin_spec"

  if [[ ! -f $plugin_manifest ]]; then
    echo "ERROR: Bun did not materialize OpenCode plugin ${plugin_spec} at ${plugin_manifest}" >&2
    exit 1
  fi

  echo "OpenCode plugin ready: ${plugin_spec}"
}

for plugin_spec in "${plugin_specs[@]}"; do
  install_plugin "$plugin_spec"
done
