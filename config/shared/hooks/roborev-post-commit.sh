#!/usr/bin/env bash
# Enqueue the committed repository state with the local RoboRev daemon.
set -euo pipefail

ROBOREV_BIN="${HOME}/.local/bin/roborev"

if [ ! -x "$ROBOREV_BIN" ]; then
  exit 0
fi

"$ROBOREV_BIN" --server "127.0.0.1:7373" post-commit --repo "$(git rev-parse --show-toplevel)" || true
