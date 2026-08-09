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

# On a distro with nix installed alongside the system (kyber: Ubuntu + nix),
# ~/.nix-profile/bin shadows the system compiler. node-gyp then links pty.node
# against the nix glibc while the runtime node uses the system loader, giving
# `GLIBC_2.42 not found` at dlopen. Pin the system toolchain there. NixOS is
# self-consistent and must keep its own compiler.
if [ ! -e /etc/NIXOS ] && [ -x /usr/bin/g++ ] && [ -x /usr/bin/gcc ]; then
  export CC=/usr/bin/gcc CXX=/usr/bin/g++
fi

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
for dir in "$HOME"/.npm/_npx/*/ "$HOME"/.t3/runtime/versions/*/; do
  pty="${dir}node_modules/node-pty"
  if [ -d "$pty" ] && [ ! -f "$pty/build/Release/pty.node" ]; then
    (cd "$dir" && npm rebuild --ignore-scripts=false node-pty >/dev/null)
  fi
done
