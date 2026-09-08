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

"${T3_PREPARE_RUNTIME:?}" "$base/runtime/versions/$version"
exec node "$base/runtime/service-launcher.mjs"
