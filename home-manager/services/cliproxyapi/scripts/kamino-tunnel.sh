#!/usr/bin/env bash
# shellcheck source=/dev/null
set -euo pipefail
. "@common@"

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
EXPECTED_HOST_PORT="${HOST}:${PORT}"

# Path to machine-local mapping (JSON array of objects with credential, host, port)
MAPPING_FILE="${HOME}/.config/cliproxyapi/kamino-tunnels.json"
if [ ! -f "$MAPPING_FILE" ]; then
  echo "⚠️  Kamino tunnel mapping not found: $MAPPING_FILE" >&2
  exit 0 # fail closed: no tunnel
fi

# Load and validate mapping
map_json=$(cat "$MAPPING_FILE")
if ! echo "$map_json" | @jq@ -e '. | length >= 0' >/dev/null 2>&1; then
  echo "⚠️  Invalid JSON in kamino tunnel mapping" >&2
  exit 0
fi

# Find entries for this host/port
matches=$(echo "$map_json" | @jq@ -c --arg host "$HOST" --arg port "$PORT" '.[] | select(.host == $host and (.port|tostring) == $port)')
if [ -z "$matches" ]; then
  echo "ℹ️  No credentials mapped to $EXPECTED_HOST_PORT" >&2
  exit 0 # fail closed: no tunnel
fi

# Extract credential filenames
credential_files=$(echo "$matches" | @jq@ -r '.credential' | sort -u)
if [ -z "$credential_files" ]; then
  echo "⚠️  No credential files found in mapping for $EXPECTED_HOST_PORT" >&2
  exit 0
fi

# Update proxy_url in each credential auth file (with lock to avoid concurrent writes)
LOCK_FILE="/tmp/cliproxyapi-tunnel-update.lock"
auth_dir="${HOME}/.cli-proxy-api/objectstore/auths"

# Function to update a single auth file
update_auth_file() {
  local filename="$1"
  local filepath="${auth_dir}/${filename}"
  if [ ! -f "$filepath" ]; then
    echo "⚠️  Auth file not found: $filepath" >&2
    return 0
  fi
  # Acquire lock (non-blocking, fail if cannot obtain quickly)
  if ! flock -n 200; then
    echo "⚠️  Could not acquire lock for auth update, skipping $filename" >&2
    return 0
  fi
  # Update proxy_url field using jq
  local new_proxy="socks5://127.0.0.1:${PORT}"
  if @jq@ --arg proxy "$new_proxy" '.proxy_url = $proxy' "$filepath" >"${filepath}.tmp" 2>/dev/null; then
    mv "${filepath}.tmp" "$filepath"
    echo "✅  Updated proxy_url in $filename to $new_proxy"
  else
    echo "⚠️  Failed to update proxy_url in $filename" >&2
  fi
  # Release lock (flock releases automatically when subshell ends)
} 200>"$LOCK_FILE"

# Update each credential file (serialized via lock)
for cred in $credential_files; do
  update_auth_file "$cred"
done

# Start SSH tunnel (exec to replace this script, so systemd can monitor it)
# Use SSH config host alias (e.g., kamino1) which includes User, IdentityFile, etc.
exec ssh -N -D "${PORT}" \
  -o ExitOnForwardFailure=yes \
  -o StrictHostKeyChecking=accept-new \
  -o ForwardAgent=no \
  -o ServerAliveInterval=60 \
  -o ServerAliveCountMax=3 \
  "${HOST}"
