#!/usr/bin/env bash
# Recover auth files from backup if missing
# Handles race condition where files get deleted during config reload

set -euo pipefail

CONFIG_DIR="$HOME/.cli-proxy-api"
BACKUP_DIR="s3://cliproxyapi/backup/auths/"
AUTH_DIR="$CONFIG_DIR/objectstore/auths"

# Check if auth directory is missing or empty
if [ ! -d "$AUTH_DIR" ] || [ -z "$(ls -A $AUTH_DIR 2>/dev/null)" ]; then
  echo "Auth files missing, attempting recovery from R2 backup..." >&2
  mkdir -p "$AUTH_DIR"
  AWS_ACCESS_KEY_ID="${OBJECTSTORE_ACCESS_KEY}" \
    AWS_SECRET_ACCESS_KEY="${OBJECTSTORE_SECRET_KEY}" \
    aws s3 sync \
    --endpoint-url="${OBJECTSTORE_ENDPOINT}" \
    --no-progress \
    "$BACKUP_DIR" \
    "$AUTH_DIR/" 2>/dev/null && echo "✅ Recovered auth files from backup" >&2 || echo "⚠️  Recovery failed (no backup available?)" >&2
fi
