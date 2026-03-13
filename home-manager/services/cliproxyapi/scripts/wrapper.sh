#!/usr/bin/env bash
# shellcheck source=/dev/null
set -euo pipefail
. "@common@"

CONFIG_DIR="${HOME}/.cli-proxy-api"
AUTH_DIR="${CONFIG_DIR}/objectstore/auths"
cliproxy_init_objectstore_env
OBJECTSTORE_LOCAL_PATH="$CONFIG_DIR"
export OBJECTSTORE_ENDPOINT OBJECTSTORE_BUCKET OBJECTSTORE_ACCESS_KEY OBJECTSTORE_SECRET_KEY OBJECTSTORE_LOCAL_PATH

if cliproxy_has_objectstore_credentials; then
  mkdir -p "$AUTH_DIR"

  if [ -n "$(ls -A "$AUTH_DIR" 2>/dev/null)" ]; then
    cliproxy_sync_auth_to_s3 "$AUTH_DIR"
  else
    cliproxy_sync_auth_from_s3 "$AUTH_DIR"
  fi
fi

cd "$CONFIG_DIR"
exec /opt/homebrew/bin/cliproxyapi "$@"
