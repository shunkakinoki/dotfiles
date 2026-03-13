#!/usr/bin/env bash
# Pull auth files from S3 to local cache
# shellcheck source=/dev/null
set -euo pipefail
. "@common@"

AUTH_DIR="${HOME}/.cli-proxy-api/objectstore/auths"
CCS_AUTH_DIR="${HOME}/.ccs/cliproxy/auth"
cliproxy_init_objectstore_env

if ! cliproxy_has_objectstore_credentials; then
  echo "⚠️  Missing S3 credentials, skipping hydrate" >&2
  exit 0
fi

cliproxy_sync_auth_from_s3 "$AUTH_DIR"

# Also sync to CCS auth dir so ccs can find the tokens
mkdir -p "$CCS_AUTH_DIR"
cp -u "$AUTH_DIR"/*.json "$CCS_AUTH_DIR/" 2>/dev/null || true
