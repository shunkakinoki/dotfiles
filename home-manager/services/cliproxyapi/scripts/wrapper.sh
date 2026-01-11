#!/usr/bin/env bash
# shellcheck source=/dev/null
set -euo pipefail

CONFIG_DIR="${HOME}/.cli-proxy-api"
AUTH_DIR="${CONFIG_DIR}/objectstore/auths"
ENV_FILE="${HOME}/dotfiles/.env"
if [ -f "$ENV_FILE" ]; then
  set -a
  . "$ENV_FILE"
  set +a
fi

strip_quotes() {
  local v="$1"
  v="${v%\"}"
  v="${v#\"}"
  printf '%s' "$v"
}

OBJECTSTORE_ENDPOINT="$(strip_quotes "${OBJECTSTORE_ENDPOINT:-}")"
OBJECTSTORE_BUCKET="$(strip_quotes "${OBJECTSTORE_BUCKET:-cliproxyapi}")"
OBJECTSTORE_ACCESS_KEY="$(strip_quotes "${OBJECTSTORE_ACCESS_KEY:-}")"
OBJECTSTORE_SECRET_KEY="$(strip_quotes "${OBJECTSTORE_SECRET_KEY:-}")"
OBJECTSTORE_LOCAL_PATH="$CONFIG_DIR"
export OBJECTSTORE_ENDPOINT OBJECTSTORE_BUCKET OBJECTSTORE_ACCESS_KEY OBJECTSTORE_SECRET_KEY OBJECTSTORE_LOCAL_PATH

if [ -n "$OBJECTSTORE_ENDPOINT" ] && [ -n "$OBJECTSTORE_ACCESS_KEY" ] && [ -n "$OBJECTSTORE_SECRET_KEY" ]; then
  mkdir -p "$AUTH_DIR"

  if [ -n "$(ls -A "$AUTH_DIR" 2>/dev/null)" ]; then
    AWS_ACCESS_KEY_ID="$OBJECTSTORE_ACCESS_KEY" \
      AWS_SECRET_ACCESS_KEY="$OBJECTSTORE_SECRET_KEY" \
      @aws@ s3 sync \
      --endpoint-url="$OBJECTSTORE_ENDPOINT" \
      --no-progress \
      "$AUTH_DIR/" \
      "s3://${OBJECTSTORE_BUCKET}/auths/" || true

    AWS_ACCESS_KEY_ID="$OBJECTSTORE_ACCESS_KEY" \
      AWS_SECRET_ACCESS_KEY="$OBJECTSTORE_SECRET_KEY" \
      @aws@ s3 sync \
      --endpoint-url="$OBJECTSTORE_ENDPOINT" \
      --no-progress \
      "$AUTH_DIR/" \
      "s3://${OBJECTSTORE_BUCKET}/backup/auths/" || true
  else
    AWS_ACCESS_KEY_ID="$OBJECTSTORE_ACCESS_KEY" \
      AWS_SECRET_ACCESS_KEY="$OBJECTSTORE_SECRET_KEY" \
      @aws@ s3 sync \
      --endpoint-url="$OBJECTSTORE_ENDPOINT" \
      --no-progress \
      "s3://${OBJECTSTORE_BUCKET}/auths/" \
      "$AUTH_DIR/" || true

    AWS_ACCESS_KEY_ID="$OBJECTSTORE_ACCESS_KEY" \
      AWS_SECRET_ACCESS_KEY="$OBJECTSTORE_SECRET_KEY" \
      @aws@ s3 sync \
      --endpoint-url="$OBJECTSTORE_ENDPOINT" \
      --no-progress \
      "s3://${OBJECTSTORE_BUCKET}/backup/auths/" \
      "$AUTH_DIR/" || true
  fi
fi

cd "$CONFIG_DIR"
exec /opt/homebrew/bin/cliproxyapi "$@"
