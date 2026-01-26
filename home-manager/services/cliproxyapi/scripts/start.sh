#!/usr/bin/env bash
# shellcheck source=/dev/null
set -euo pipefail

CONFIG_DIR="${HOME}/.cli-proxy-api"
TEMPLATE="$CONFIG_DIR/config.template.yaml"
CONFIG="$CONFIG_DIR/config.yaml"
ENV_FILE="${HOME}/dotfiles/.env"
AUTH_DIR="${CONFIG_DIR}/objectstore/auths"
USAGE_EXPORT_FILE="${CONFIG_DIR}/usage-export.json"
MANAGEMENT_URL="${CLIPROXY_MANAGEMENT_URL:-http://127.0.0.1:8317/v0/management}"

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
MANAGEMENT_KEY="${CLIPROXY_MANAGEMENT_PASSWORD:-${CLIPROXY_MANAGEMENT_KEY:-}}"
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

# Push config to objectstore so remote-backed config doesn't revert locally
if [ -n "$OBJECTSTORE_ENDPOINT" ] && [ -n "$OBJECTSTORE_ACCESS_KEY" ] && [ -n "$OBJECTSTORE_SECRET_KEY" ]; then
  AWS_ACCESS_KEY_ID="$OBJECTSTORE_ACCESS_KEY" \
    AWS_SECRET_ACCESS_KEY="$OBJECTSTORE_SECRET_KEY" \
    @aws@ s3 sync \
    --endpoint-url="$OBJECTSTORE_ENDPOINT" \
    --no-progress \
    "$OBJECTSTORE_CONFIG_DIR/" \
    "s3://${OBJECTSTORE_BUCKET}/config/" || true

  AWS_ACCESS_KEY_ID="$OBJECTSTORE_ACCESS_KEY" \
    AWS_SECRET_ACCESS_KEY="$OBJECTSTORE_SECRET_KEY" \
    @aws@ s3 sync \
    --endpoint-url="$OBJECTSTORE_ENDPOINT" \
    --no-progress \
    "$BACKUP_CONFIG_DIR/" \
    "s3://${OBJECTSTORE_BUCKET}/backup/config/" || true
fi

cd "$CONFIG_DIR"

# Linux: Docker
usage_import() {
  if [ -z "$MANAGEMENT_KEY" ] || [ ! -f "$USAGE_EXPORT_FILE" ]; then
    return 0
  fi
  curl -sS \
    -H "Authorization: Bearer ${MANAGEMENT_KEY}" \
    -H "Content-Type: application/json" \
    -X POST \
    --data-binary @"$USAGE_EXPORT_FILE" \
    "${MANAGEMENT_URL}/usage/import" >/dev/null || true
}

# shellcheck disable=SC2329 # Invoked via trap
usage_export() {
  if [ -z "$MANAGEMENT_KEY" ]; then
    return 0
  fi
  mkdir -p "$(dirname "$USAGE_EXPORT_FILE")"
  curl -sS \
    -H "Authorization: Bearer ${MANAGEMENT_KEY}" \
    "${MANAGEMENT_URL}/usage/export" \
    -o "$USAGE_EXPORT_FILE" || true
}

wait_for_management() {
  if [ -z "$MANAGEMENT_KEY" ]; then
    return 0
  fi
  local attempts=60
  for _ in $(seq 1 "$attempts"); do
    if curl -sS \
      -H "Authorization: Bearer ${MANAGEMENT_KEY}" \
      "${MANAGEMENT_URL}/usage/export" \
      -o /dev/null; then
      return 0
    fi
    sleep 3
  done
  return 1
}

child_pid=""
trap 'usage_export' EXIT
trap 'usage_export; if [ -n "$child_pid" ]; then kill -TERM "$child_pid" 2>/dev/null || true; wait "$child_pid" 2>/dev/null || true; fi' TERM INT

if [ "$(uname)" = "Linux" ] && command -v docker >/dev/null 2>&1; then
  if docker info >/dev/null 2>&1; then
    echo "🔄 Pulling latest cliproxyapi image..."
    docker pull eceasy/cli-proxy-api:latest || true
  else
    echo "⏭️ Skipping docker pull (docker not accessible)"
  fi

  docker rm -f cliproxyapi 2>/dev/null || true
  mkdir -p "$CONFIG_DIR/logs"
  docker run --rm \
    --name cliproxyapi \
    --network host \
    --ulimit nofile=65536:65536 \
    -v "$CONFIG:/CLIProxyAPI/config.yaml:ro" \
    -v "$CONFIG_DIR:/root/.cli-proxy-api" \
    -v "$CONFIG_DIR/logs:/CLIProxyAPI/logs" \
    -e MANAGEMENT_PASSWORD="${MANAGEMENT_PASSWORD:-}" \
    eceasy/cli-proxy-api:latest &
  child_pid=$!
  wait_for_management || true
  usage_import
  wait "$child_pid"
  exit $?
fi

# macOS: Homebrew binary
if [ -x /opt/homebrew/bin/cliproxyapi ]; then
  /opt/homebrew/bin/cliproxyapi -config "$CONFIG" "$@" &
  child_pid=$!
  wait_for_management || true
  usage_import
  wait "$child_pid"
  exit $?
elif [ -x /usr/local/bin/cliproxyapi ]; then
  /usr/local/bin/cliproxyapi -config "$CONFIG" "$@" &
  child_pid=$!
  wait_for_management || true
  usage_import
  wait "$child_pid"
  exit $?
else
  echo "cliproxyapi not found" >&2
  exit 1
fi
