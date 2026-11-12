#!/usr/bin/env bash
# @beadsDir@, @doltServerConfig@, and @dolt@ are substituted by pkgs.replaceVars.
set -euo pipefail

# Data reconciliation and restoration are operator-owned operations. Starting
# the authority never moves, replaces, or imports a preserved replica.
if [ ! -d "@beadsDir@" ]; then
  echo "Authoritative Beads data directory is missing; provision or restore it before starting Dolt" >&2
  exit 1
fi

exec "@dolt@/bin/dolt" sql-server --config "@doltServerConfig@"
