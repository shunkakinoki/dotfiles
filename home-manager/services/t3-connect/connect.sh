#!/usr/bin/env bash
# Pre-warm the npx cache for the T3 remote server and build its native modules.
#
# T3's desktop client launches `npx t3@<version>` over SSH and gives it a short
# deadline to listen on 127.0.0.1:3773. A cold install is slow enough to miss
# that deadline; npm then gets SIGTERM'd mid-reify and leaves a partial tree
# that poisons every later attempt. Warming the cache keeps startup ~2s.
#
# node-pty ships no linux-x64 prebuild, so it needs its install script to
# compile pty.node. Global ignore-scripts=true blocks that, and npm has no
# per-package allowlist, so rebuild just that one package with a scoped
# override rather than weakening the default.

set -euo pipefail

TAG="${T3_CONNECT_TAG:-nightly}"

# A native addon must be built by a compiler whose libc matches the node that
# loads it: a nix-gcc build needs the nix glibc and fails dlopen under a
# generic node (`GLIBC_2.42 not found`), and vice versa. Everything here is
# nix -- the unit's PATH supplies both nix gcc and nix nodejs, and `t3 service`
# is installed against the same nix node -- so the pair stays consistent with
# no distro toolchain involved.
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
# Gate on loading, not on the file existing. A build with the wrong toolchain
# still drops pty.node, so a presence check would treat a binary that fails
# dlopen as done and skip it forever.
for dir in "$HOME"/.npm/_npx/*/ "$HOME"/.t3/runtime/versions/*/; do
  pty="${dir}node_modules/node-pty"
  [ -d "$pty" ] || continue
  if node -e 'require(process.argv[1])' "$pty" >/dev/null 2>&1; then
    continue
  fi
  rm -rf "${pty:?}/build"
  (cd "$dir" && npm rebuild --ignore-scripts=false node-pty >/dev/null)
done
