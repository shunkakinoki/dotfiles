#!/usr/bin/env bash
# Recover auth files from R2 if missing locally
# Handles race condition where files get deleted during config reload

set -euo pipefail

CONFIG_DIR="$HOME/.cli-proxy-api"
MAIN_DIR="s3://cliproxyapi/auths/"
BACKUP_DIR="s3://cliproxyapi/backup/auths/"
AUTH_DIR="$CONFIG_DIR/objectstore/auths"

# Check if auth directory is missing or empty
if [ ! -d "$AUTH_DIR" ] || [ -z "$(ls -A "$AUTH_DIR" 2>/dev/null)" ]; then
  echo "Auth files missing locally, attempting recovery from R2..." >&2
  mkdir -p "$AUTH_DIR"

  if [ -z "${OBJECTSTORE_ENDPOINT:-}" ]; then
    echo "⚠️  OBJECTSTORE_ENDPOINT not set, skipping recovery" >&2
  else
    # Try main auths/ location first
    if AWS_ACCESS_KEY_ID="${OBJECTSTORE_ACCESS_KEY}" \
      AWS_SECRET_ACCESS_KEY="${OBJECTSTORE_SECRET_KEY}" \
      @aws@ s3 sync \
      --endpoint-url="${OBJECTSTORE_ENDPOINT}" \
      --no-progress \
      "$MAIN_DIR" \
      "$AUTH_DIR/" 2>/dev/null; then
      echo "✅ Recovered auth files from auths/" >&2
    else
      # Fall back to backup location
      echo "Main location empty, trying backup..." >&2
      AWS_ACCESS_KEY_ID="${OBJECTSTORE_ACCESS_KEY}" \
        AWS_SECRET_ACCESS_KEY="${OBJECTSTORE_SECRET_KEY}" \
        @aws@ s3 sync \
        --endpoint-url="${OBJECTSTORE_ENDPOINT}" \
        --no-progress \
        "$BACKUP_DIR" \
        "$AUTH_DIR/" 2>/dev/null && echo "✅ Recovered from backup/auths/" >&2 || echo "⚠️  Recovery failed" >&2
    fi
  fi
fi
