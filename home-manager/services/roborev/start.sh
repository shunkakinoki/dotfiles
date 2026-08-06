#!/usr/bin/env bash
set -euo pipefail

ROBOREV_BIN="$1"
SERVER_ADDR="$2"
ENV_FILE="${HOME}/dotfiles/.env"

if [ -f "$ENV_FILE" ]; then
  set -a
  # shellcheck source=/dev/null
  . "$ENV_FILE"
  set +a
fi

exec "$ROBOREV_BIN" daemon run --addr "$SERVER_ADDR"
