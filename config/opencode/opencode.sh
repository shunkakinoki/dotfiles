#!/usr/bin/env bash
# The installer links this wrapper over bun's `opencode` shim, so every caller
# that resolves `opencode` on PATH gets the v2 database and standalone mode.
set -euo pipefail

bin="${BUN_INSTALL:-$HOME/.bun}/install/global/node_modules/@opencode/cli/bin/opencode.exe"
if [ ! -x "$bin" ]; then
  echo "opencode: @opencode/cli is not installed at $bin" >&2
  exit 127
fi

# Keeps v2 off the 1.x opencode.db so 1.x history is never read or rewritten.
export OPENCODE_DB=opencode-v2.db

case "${1:-}" in
run)
  shift
  exec "$bin" run --standalone "$@"
  ;;
upgrade | update | uninstall | acp | api | debug | auth | mcp | plugin | models | stats | mini | session | service | reload | pair | serve)
  exec "$bin" "$@"
  ;;
esac

# The v2 TUI has no --model flag; failing loudly beats seating the default model.
for arg in "$@"; do
  case "$arg" in
  --model | --model=* | -m | -m=*)
    echo "opencode: the v2 TUI takes no --model; seat it with OPENCODE_CONFIG_CONTENT='{\"model\":\"<provider>/<model>\"}'" >&2
    exit 64
    ;;
  esac
done

# Without --standalone the TUI attaches to a shared background service, which
# would couple every pane's lifetime and config to whichever pane started it.
exec "$bin" --standalone "$@"
