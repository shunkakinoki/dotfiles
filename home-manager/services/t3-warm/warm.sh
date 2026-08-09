#!/usr/bin/env bash
# Pre-warm the npx cache for the T3 remote server.
#
# T3's desktop client launches `npx t3@nightly` over SSH and gives it a short
# deadline to listen on 127.0.0.1:3773. A cold install is slow enough to miss
# that deadline; npm then gets SIGTERM'd mid-reify and leaves a partial tree
# that poisons every later attempt. Warming the cache keeps startup ~2s.
#
# node-pty also ships no linux-x64 prebuild, so it needs its install script to
# compile pty.node. Global ignore-scripts=true blocks that, and npm has no
# per-package allowlist, so rebuild just that one package with a scoped
# override rather than weakening the default.

set -euo pipefail

TAG="${T3_WARM_TAG:-nightly}"

npx --yes "t3@${TAG}" --version >/dev/null

for dir in "$HOME"/.npm/_npx/*/; do
  pty="${dir}node_modules/node-pty"
  if [ -d "$pty" ] && [ ! -f "$pty/build/Release/pty.node" ]; then
    (cd "$dir" && npm rebuild --ignore-scripts=false node-pty >/dev/null)
  fi
done
