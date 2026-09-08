#!/usr/bin/env bash
# Pre-warm the npx cache for the T3 remote server and build its native modules.
#
# T3's desktop client launches `npx t3@<version>` over SSH and gives it a short
# deadline to listen on 127.0.0.1:3773. A cold install is slow enough to miss
# that deadline; npm then gets SIGTERM'd mid-reify and leaves a partial tree
# that poisons every later attempt. Warming the cache keeps startup ~2s.
#
# Native preparation uses a per-package allowlist in the runtime itself.
# The global npm script policy stays unchanged.

set -euo pipefail

TAG="${T3_CONNECT_TAG:-nightly}"

# A native addon must be built by a compiler whose libc matches the node that
# loads it; a mismatched pair can fail with `GLIBC_2.42 not found`. Home Manager
# supplies the same Nix toolchain to preparation and the service launcher.
#
# npx keys its cache dir on the literal spec string, not the resolved version,
# so `t3@nightly` and `t3@0.0.33-nightly.20260809.1041` land in different dirs.
# The client resolves the tag before invoking npx, so warm the exact version or
# we warm a directory the client never reads.
version="$(npm view "t3@${TAG}" version 2>/dev/null || true)"
spec="t3@${version:-$TAG}"

npx --yes "$spec" --version >/dev/null

# Two independent trees need the native module: the npx cache used by the
# client's SSH launch, and the runtime `t3 service` installs for its systemd
# unit.
#
# The helper verifies a terminal spawn both before and after rebuilding.
for dir in "${npm_config_cache:-$HOME/.npm}"/_npx/*/ "${T3CODE_HOME:-$HOME/.t3}"/runtime/versions/*/; do
  pty="${dir}node_modules/node-pty"
  [ -d "$pty" ] || continue
  "${T3_PREPARE_RUNTIME:?}" "$dir"
done
