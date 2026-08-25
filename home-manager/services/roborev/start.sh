#!/usr/bin/env bash
set -euo pipefail

ROBOREV_BIN="$1"
SERVER_ADDR="$2"
PORT_CLEANUP_BIN="${3:-}"
ENV_FILE="${HOME}/dotfiles/.env"

if [ -f "$ENV_FILE" ]; then
  set -a
  # shellcheck source=/dev/null
  . "$ENV_FILE"
  set +a
fi

if [ "$(uname -s)" = "Darwin" ] && [ -x "$PORT_CLEANUP_BIN" ]; then
  server_port="${SERVER_ADDR##*:}"
  listener_pids="$(
    "$PORT_CLEANUP_BIN" -nP -t -iTCP:"$server_port" -sTCP:LISTEN 2>/dev/null || true
  )"

  while IFS= read -r listener_pid; do
    if [[ "$listener_pid" =~ ^[0-9]+$ ]]; then
      kill -KILL "$listener_pid" 2>/dev/null || true
    fi
  done <<<"$listener_pids"
fi

exec "$ROBOREV_BIN" daemon run --addr "$SERVER_ADDR"
