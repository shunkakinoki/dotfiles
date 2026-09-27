#!/usr/bin/env bash
# NixOS has no FHS /usr/lib, so the T3 runtime needs the desktop library set
# from the Nix store there. Other distros ship those libraries, and a Nix-built
# copy links a newer glibc than the system, so only the GCC runtime is safe:
# expose it or the agents T3 spawns abort with "GLIBC_ABI_GNU2_TLS not found".
set -euo pipefail

if [ -e /etc/NIXOS ]; then
  printf '%s\n' "${T3_NIXOS_LIBRARY_PATH:?}"
else
  printf '%s\n' "${T3_SYSTEM_LIBRARY_PATH:?}"
fi
