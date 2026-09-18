#!/usr/bin/env bash
set -euo pipefail

# Usage: kamino-tunnel.sh <index>
#   <index>: positive integer (1, 2, 3, ...) corresponding to kamino<index> and port 1080+<index>

if [ $# -ne 1 ]; then
  echo "Usage: $0 <index (positive integer)>" >&2
  exit 1
fi

INDEX="$1"
if ! [[ $INDEX =~ ^[1-9][0-9]*$ ]]; then
  echo "Index must be a positive integer" >&2
  exit 1
fi

HOST="kamino${INDEX}"
PORT=$((1080 + INDEX))
PROXY_URL="socks5://127.0.0.1:${PORT}"

# Machine-local JSON array of {credential, host, port} and
# {provider, key_index, host, port}; it names real accounts, so it is not
# managed by Nix. start.sh renders the API key entries into its config.
MAPPING_FILE="${HOME}/.config/cliproxyapi/kamino-tunnels.json"
AUTH_DIR="${HOME}/.cli-proxy-api/objectstore/auths"
# Shared with start.sh, which rewrites proxy_url on every service start.
LOCK_FILE="${HOME}/.cli-proxy-api/proxy-url.lock"

if [ ! -f "$MAPPING_FILE" ]; then
  echo "ℹ️  No kamino tunnel mapping at $MAPPING_FILE; not starting $HOST" >&2
  exit 0
fi

# shellcheck disable=SC2016
if ! mapped="$(@jq@ -c --arg host "$HOST" --argjson port "$PORT" \
  '[.[] | select(.host == $host and .port == $port)]' "$MAPPING_FILE")"; then
  echo "⚠️  Invalid JSON in kamino tunnel mapping: $MAPPING_FILE" >&2
  exit 1
fi

if [ "$mapped" = "[]" ]; then
  echo "ℹ️  Nothing mapped to ${HOST}:${PORT}; not starting tunnel" >&2
  exit 0
fi

credential_files="$(@jq@ -r '.[].credential // empty' <<<"$mapped")"

mkdir -p "$(dirname "$LOCK_FILE")"
(
  @flock@ -w 30 200 || {
    echo "⚠️  Timed out waiting for the proxy URL lock" >&2
    exit 1
  }
  while IFS= read -r cred; do
    [ -n "$cred" ] || continue
    filepath="${AUTH_DIR}/${cred}"
    if [ ! -f "$filepath" ]; then
      echo "⚠️  Auth file not found: $filepath" >&2
      continue
    fi
    # shellcheck disable=SC2016
    @jq@ --arg proxy "$PROXY_URL" '.proxy_url = $proxy' "$filepath" >"${filepath}.tmp"
    mv "${filepath}.tmp" "$filepath"
    echo "✅  $cred -> $PROXY_URL"
  done <<<"$credential_files"
) 200>"$LOCK_FILE"

# Mapped credentials keep pointing at this port while the tunnel is down, so
# their traffic fails instead of leaking out of the host's own IP.
exec @ssh@ -N -D "127.0.0.1:${PORT}" \
  -o ExitOnForwardFailure=yes \
  -o StrictHostKeyChecking=yes \
  -o BatchMode=yes \
  -o ForwardAgent=no \
  -o ServerAliveInterval=60 \
  -o ServerAliveCountMax=3 \
  "${HOST}"
