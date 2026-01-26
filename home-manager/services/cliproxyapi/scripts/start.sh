#!/usr/bin/env bash
# shellcheck source=/dev/null
set -euo pipefail

CONFIG_DIR="${HOME}/.cli-proxy-api"
TEMPLATE="$CONFIG_DIR/config.template.yaml"
CONFIG="$CONFIG_DIR/config.yaml"
ENV_FILE="${HOME}/dotfiles/.env"
AUTH_DIR="${CONFIG_DIR}/objectstore/auths"

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
MANAGEMENT_PASSWORD="${CLIPROXY_MANAGEMENT_PASSWORD:-}"
export OBJECTSTORE_ENDPOINT OBJECTSTORE_BUCKET OBJECTSTORE_ACCESS_KEY OBJECTSTORE_SECRET_KEY OBJECTSTORE_LOCAL_PATH MANAGEMENT_PASSWORD

if [ -n "$OBJECTSTORE_ENDPOINT" ] && [ -n "$OBJECTSTORE_ACCESS_KEY" ] && [ -n "$OBJECTSTORE_SECRET_KEY" ]; then
  mkdir -p "$AUTH_DIR"

  if [ -z "$(ls -A "$AUTH_DIR" 2>/dev/null)" ]; then
    echo "⚠️  Local auth cache empty; hydrating from S3" >&2
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
  fi
fi

# Generate config from template
if [ -f "$TEMPLATE" ]; then
  @sed@ \
    -e "s|__OPENROUTER_API_KEY__|${OPENROUTER_API_KEY:-}|g" \
    -e "s|__CLIPROXY_MANAGEMENT_PASSWORD__|${CLIPROXY_MANAGEMENT_PASSWORD:-}|g" \
    -e "s|__ZAI_API_KEY__|${ZAI_API_KEY:-}|g" \
    -e "s|__AMP_UPSTREAM_API_KEY__|${AMP_UPSTREAM_API_KEY:-}|g" \
    "$TEMPLATE" >"$CONFIG"

  if [ "$(uname)" = "Linux" ] && [ -n "${CLIPROXY_API_KEY:-}" ]; then
    @sed@ -i \
      -e "s|^# api-keys:|api-keys:|" \
      -e "s|^#   - \"__CLIPROXY_API_KEY__\"|  - \"${CLIPROXY_API_KEY}\"|" \
      "$CONFIG"
  fi

  # Disable AMP on Linux (causes routing issues with antigravity provider)
  if [ "$(uname)" = "Linux" ]; then
    @sed@ -i \
      -e "s|^ampcode:|# ampcode:|" \
      -e "s|^  upstream-url:|#   upstream-url:|" \
      -e "s|^  upstream-api-key:|#   upstream-api-key:|" \
      -e "s|^  restrict-management-to-localhost:|#   restrict-management-to-localhost:|" \
      -e "s|^  # Map non-prefixed|#   # Map non-prefixed|" \
      -e "s|^  model-mappings:|#   model-mappings:|" \
      -e "s|^    - from:|#     - from:|" \
      -e "s|^      to:|#       to:|" \
      "$CONFIG"
  fi
fi

# Keep objectstore-backed config in sync for management UI
OBJECTSTORE_CONFIG_DIR="$CONFIG_DIR/objectstore/config"
OBJECTSTORE_CONFIG="$OBJECTSTORE_CONFIG_DIR/config.yaml"
BACKUP_CONFIG_DIR="$CONFIG_DIR/backup/config"
BACKUP_CONFIG="$BACKUP_CONFIG_DIR/config.yaml"
mkdir -p "$OBJECTSTORE_CONFIG_DIR" "$BACKUP_CONFIG_DIR"
rm -f "$OBJECTSTORE_CONFIG" "$BACKUP_CONFIG"
cp "$CONFIG" "$OBJECTSTORE_CONFIG"
cp "$CONFIG" "$BACKUP_CONFIG"

cd "$CONFIG_DIR"

# Linux: Docker
if [ "$(uname)" = "Linux" ] && command -v docker >/dev/null 2>&1; then
  docker rm -f cliproxyapi 2>/dev/null || true
  mkdir -p "$CONFIG_DIR/logs"
  exec docker run --rm \
    --name cliproxyapi \
    --network host \
    --ulimit nofile=65536:65536 \
    -v "$CONFIG:/CLIProxyAPI/config.yaml:ro" \
    -v "$CONFIG_DIR:/root/.cli-proxy-api" \
    -v "$CONFIG_DIR/logs:/CLIProxyAPI/logs" \
    -e MANAGEMENT_PASSWORD="${MANAGEMENT_PASSWORD:-}" \
    eceasy/cli-proxy-api:latest
fi

# macOS: Homebrew binary
if [ -x /opt/homebrew/bin/cliproxyapi ]; then
  exec /opt/homebrew/bin/cliproxyapi -config "$CONFIG" "$@"
elif [ -x /usr/local/bin/cliproxyapi ]; then
  exec /usr/local/bin/cliproxyapi -config "$CONFIG" "$@"
else
  echo "cliproxyapi not found" >&2
  exit 1
fi
