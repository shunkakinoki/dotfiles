#!/usr/bin/env bash
set -euo pipefail

base="${T3CODE_HOME:-$HOME/.t3}"
version="$(node -e '
  const state = require(process.argv[1]);
  if (!/^[0-9]+\.[0-9]+\.[0-9]+(?:-[0-9A-Za-z.-]+)?(?:\+[0-9A-Za-z.-]+)?$/.test(state.activeVersion)) {
    throw new Error("Invalid active T3 runtime version");
  }
  process.stdout.write(state.activeVersion);
' "$base/runtime/service-state.json")"
runtime="$base/runtime/versions/$version"

"${T3_PREPARE_RUNTIME:?}" "$runtime"
# Standalone releases (launcher protocol 3) host the launcher in their own
# executable; npm-installed runtimes still use the Node launcher script.
if [ -x "$runtime/t3" ]; then
  exec "$runtime/t3" __service-launcher
fi
exec node "$base/runtime/service-launcher.mjs"
