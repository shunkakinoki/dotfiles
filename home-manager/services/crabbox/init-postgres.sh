#!/usr/bin/env bash
set -euo pipefail

DATA_DIR="@dataDir@"
SOCKET_DIR="@socketDir@"

mkdir -p "$DATA_DIR" "$SOCKET_DIR"
chmod 700 "$DATA_DIR" "$SOCKET_DIR"

if [ ! -s "$DATA_DIR/PG_VERSION" ]; then
  "@initdb@" \
    --pgdata="$DATA_DIR" \
    --username="@databaseAdmin@" \
    --auth-local=peer \
    --auth-host=scram-sha-256 \
    --encoding=UTF8 \
    --no-locale
fi
