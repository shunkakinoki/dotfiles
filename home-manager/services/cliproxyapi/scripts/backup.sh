#!/usr/bin/env bash
# Push auth files from local cache to S3
# shellcheck source=/dev/null
set -euo pipefail
. "@common@"

AUTH_DIR="${HOME}/.cli-proxy-api/objectstore/auths"
CCS_AUTH_DIR="${HOME}/.ccs/cliproxy/auth"
cliproxy_init_objectstore_env

if ! cliproxy_has_objectstore_credentials; then
  echo "⚠️  Missing S3 credentials, skipping backup" >&2
  exit 0
fi

if [ ! -d "$AUTH_DIR" ] || [ -z "$(ls -A "$AUTH_DIR" 2>/dev/null)" ]; then
  echo "⚠️  No auth files to backup" >&2
  exit 0
fi

echo "[$(date)] Backing up auth files..." >&2

cliproxy_sync_auth_to_s3 "$AUTH_DIR"

# Also sync back to CCS auth dir so ccs can find the tokens
mkdir -p "$CCS_AUTH_DIR"
cp -u "$AUTH_DIR"/*.json "$CCS_AUTH_DIR/" 2>/dev/null || true
