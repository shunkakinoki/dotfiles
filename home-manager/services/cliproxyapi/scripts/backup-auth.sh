#!/usr/bin/env bash
# Backup auth files to R2 before service start
# Protects against race condition deletions

set -euo pipefail

CONFIG_DIR="$HOME/.cli-proxy-api"
BACKUP_DIR="s3://cliproxyapi/backup/auths/"
AUTH_DIR="$CONFIG_DIR/objectstore/auths"

# Check if auth directory has files
if [ -d "$AUTH_DIR" ] && [ -n "$(ls -A $AUTH_DIR 2>/dev/null)" ]; then
  echo "Backing up auth files to R2 backup directory..." >&2
  AWS_ACCESS_KEY_ID="${OBJECTSTORE_ACCESS_KEY}" \
    AWS_SECRET_ACCESS_KEY="${OBJECTSTORE_SECRET_KEY}" \
    aws s3 sync \
    --endpoint-url="${OBJECTSTORE_ENDPOINT}" \
    --no-progress \
    "$AUTH_DIR/" \
    "$BACKUP_DIR" 2>/dev/null || echo "⚠️  Backup failed (continuing anyway)" >&2
fi
