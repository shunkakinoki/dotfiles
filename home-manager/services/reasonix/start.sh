#!/usr/bin/env bash
# Start the durable Reasonix serve worker.
#
# The worker is one long-lived `reasonix serve` process. Sessions ("threads")
# accumulate inside it, so the desktop app and `reasonix attach` can list,
# open, and steer any of them without restarting the engine.
set -euo pipefail

# Use the shared shell injector on every server start, including after login,
# so CLIProxy credentials resolve the same way they do interactively.
# shellcheck source=/dev/null
. "${HOME}/.config/shell/load-env-file.sh"
_hm_load_env_file

BIN="${1:?reasonix executable required}"
STATE_DIR="${2:?state directory required}"

mkdir -p "$STATE_DIR"
chmod 700 "$STATE_DIR"

# Reasonix requires the token file to already hold a secret: it reads the file
# rather than generating one, and rejects an empty token. Generate once and
# reuse, so an attach client keeps working across restarts.
TOKEN_FILE="${STATE_DIR}/token"
if [ ! -s "$TOKEN_FILE" ]; then
  umask 077
  head -c 32 /dev/urandom | od -An -tx1 | tr -d ' \n' >"$TOKEN_FILE"
  chmod 600 "$TOKEN_FILE"
fi

# Bind an ephemeral loopback port and publish it. A fixed port would collide
# with the desktop app's own serve, so the port file is the contract clients
# read instead of a constant.
exec "$BIN" serve \
  --addr 127.0.0.1:0 \
  --auth token \
  --token-file "$TOKEN_FILE" \
  --port-file "${STATE_DIR}/port" \
  --pid-file "${STATE_DIR}/pid" \
  --session-events \
  --no-open
