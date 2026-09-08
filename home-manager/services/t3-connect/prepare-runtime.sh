#!/usr/bin/env bash
set -euo pipefail

runtime="$(realpath -e -- "${1:?runtime directory required}")"
pty="$runtime/node_modules/node-pty"
[ -d "$pty" ] || {
  echo "T3 runtime has no node-pty: $runtime" >&2
  exit 1
}

# The updater and cache warmer may prepare the same runtime concurrently.
exec 9>"$runtime/.native-prepare.lock"
flock 9

if node "${T3_PTY_PROBE:?}" "$pty" >/dev/null 2>&1; then
  exit 0
fi

echo "Preparing T3 native terminal: $runtime" >&2
cd "$runtime"
# npm's project policy must live in package.json, not a CLI flag or env var.
# Rebuild only node-pty; do not enable lifecycle scripts for the whole tree.
npm pkg set 'allowScripts.node-pty=true' --json
npm rebuild --ignore-scripts=false --foreground-scripts node-pty

# npm can exit zero even when it skips install scripts. A usable terminal,
# checked under the service's Node runtime, is the success criterion.
node "${T3_PTY_PROBE:?}" "$pty"
