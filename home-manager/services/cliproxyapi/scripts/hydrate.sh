#!/usr/bin/env bash
# Pull auth files from S3 to local cache
# shellcheck source=/dev/null
set -euo pipefail
. "@common@"

AUTH_DIR="${HOME}/.cli-proxy-api/objectstore/auths"
cliproxy_init_objectstore_env

if ! cliproxy_has_objectstore_credentials; then
  echo "⚠️  Missing S3 credentials, skipping hydrate" >&2
  exit 0
fi

# The local copies carry rotated refresh tokens that may never have reached
# S3, and `s3 sync` overwrites any local file whose size differs, so pulling
# into a populated cache reverts live credentials to revoked ones.
if [ -n "$(ls -A "$AUTH_DIR" 2>/dev/null)" ]; then
  exit 0
fi

cliproxy_sync_auth_from_s3 "$AUTH_DIR"
