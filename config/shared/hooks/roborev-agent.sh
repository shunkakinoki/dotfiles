#!/usr/bin/env bash
# Feed agent-hook events to the RoboRev daemon running on this host.
set -euo pipefail

ROBOREV_BIN="${HOME}/.local/bin/roborev"

if [ ! -x "$ROBOREV_BIN" ]; then
  exit 0
fi

exec "$ROBOREV_BIN" --server "127.0.0.1:7373" agent-hook run
