#!/usr/bin/env bash
# Ensure a system C/C++ toolchain exists for building native node addons.
#
# Kyber runs Ubuntu with nix layered on top, so ~/.nix-profile/bin shadows the
# system compiler. node-gyp then links native addons (node-pty) against the nix
# glibc, while the runtime node -- a generic build managed by fnm -- uses the
# system loader. dlopen fails with `GLIBC_2.42 not found` even though the .node
# file was produced successfully.
#
# Nix cannot fix this: every nix compiler targets the nix glibc, which is the
# problem, not the cure. The build has to use the distro toolchain, and Ubuntu
# ships gcc without g++. build-essential supplies gcc, g++, make and libc6-dev
# against the system glibc.
set -euo pipefail

if [ -x /usr/bin/g++ ]; then
  exit 0
fi

SUDO_CMD=""
if command -v sudo >/dev/null 2>&1; then
  SUDO_CMD="sudo"
elif [ -x /usr/bin/sudo ]; then
  SUDO_CMD="/usr/bin/sudo"
elif command -v doas >/dev/null 2>&1; then
  SUDO_CMD="doas"
elif [ "$(id -u)" -ne 0 ]; then
  echo "Installing build-essential requires root, but sudo/doas is not available." >&2
  exit 1
fi

run_root_cmd() {
  if [ -n "$SUDO_CMD" ]; then
    "$SUDO_CMD" "$@"
  else
    "$@"
  fi
}

echo "Installing build-essential (node-gyp needs a system g++)..."
run_root_cmd apt-get update
run_root_cmd apt-get install -y build-essential

if [ ! -x /usr/bin/g++ ]; then
  echo "/usr/bin/g++ still missing; native node addons will not load." >&2
  exit 1
fi
