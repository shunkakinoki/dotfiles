#!/usr/bin/env bash
# The T3 desktop SSH launcher runs the native t3 binary against the system
# libraries, and that binary links libatomic, which Ubuntu server images omit.
# The Nix GCC runtime cannot stand in: its libstdc++ needs a newer glibc than
# Ubuntu 22.04 ships.
set -euo pipefail

if dpkg-query -W -f='${Status}' libatomic1 2>/dev/null | grep -q 'install ok installed'; then
  exit 0
fi

echo "Installing libatomic1 for the T3 runtime (requires root)..."
SUDO=""
if [ "$(id -u)" -ne 0 ]; then
  SUDO="sudo"
fi
$SUDO env DEBIAN_FRONTEND=noninteractive apt-get install -y -qq libatomic1
