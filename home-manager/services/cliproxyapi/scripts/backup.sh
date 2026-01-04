#!/usr/bin/env bash
# Push auth files from local cache to S3
set -euo pipefail

AUTH_DIR="${HOME}/.cli-proxy-api/objectstore/auths"
CCS_AUTH_DIR="${HOME}/.ccs/cliproxy/auth"
ENV_FILE="${HOME}/dotfiles/.env"

if [ -f "$ENV_FILE" ]; then
  set -a
  . "$ENV_FILE"
  set +a
fi

strip_quotes() { local v="$1"; v="${v%\"}"; v="${v#\"}"; printf '%s' "$v"; }
ENDPOINT="$(strip_quotes "${OBJECTSTORE_ENDPOINT:-}")"
ACCESS_KEY="$(strip_quotes "${OBJECTSTORE_ACCESS_KEY:-}")"
SECRET_KEY="$(strip_quotes "${OBJECTSTORE_SECRET_KEY:-}")"

if [ -z "$ENDPOINT" ] || [ -z "$ACCESS_KEY" ] || [ -z "$SECRET_KEY" ]; then
  echo "⚠️  Missing S3 credentials, skipping backup" >&2
  exit 0
fi

if [ ! -d "$AUTH_DIR" ] || [ -z "$(ls -A "$AUTH_DIR" 2>/dev/null)" ]; then
  echo "⚠️  No auth files to backup" >&2
  exit 0
fi

echo "[$(date)] Backing up auth files..." >&2

AWS_ACCESS_KEY_ID="$ACCESS_KEY" \
AWS_SECRET_ACCESS_KEY="$SECRET_KEY" \
@aws@ s3 sync \
  --endpoint-url="$ENDPOINT" \
  --no-progress \
  "$AUTH_DIR/" \
  "s3://cliproxyapi/auths/" && echo "✅ Backed up to S3 auths/" >&2

AWS_ACCESS_KEY_ID="$ACCESS_KEY" \
AWS_SECRET_ACCESS_KEY="$SECRET_KEY" \
@aws@ s3 sync \
  --endpoint-url="$ENDPOINT" \
  --no-progress \
  "$AUTH_DIR/" \
  "s3://cliproxyapi/backup/auths/" && echo "✅ Backed up to S3 backup/auths/" >&2

# Also sync back to CCS auth dir so ccs can find the tokens
mkdir -p "$CCS_AUTH_DIR"
cp -u "$AUTH_DIR"/*.json "$CCS_AUTH_DIR/" 2>/dev/null || true
