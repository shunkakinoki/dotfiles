#!/usr/bin/env bash

set -euo pipefail

CONFIG_DIR="$HOME/.cli-proxy-api"
TEMPLATE="$CONFIG_DIR/config.template.yaml"
CONFIG="$CONFIG_DIR/config.yaml"
ENV_FILE="$HOME/dotfiles/.env"

# Source .env file to get API keys
if [ -f "$ENV_FILE" ]; then
  set -a
  # shellcheck source=/dev/null
  source "$ENV_FILE"
  set +a
fi

# Export management password for Management API (CLIProxyAPI requires MANAGEMENT_PASSWORD env var)
export MANAGEMENT_PASSWORD="${CLIPROXY_MANAGEMENT_PASSWORD:-}"

# Export S3-compatible object storage env vars (needed for backup/recovery)
export OBJECTSTORE_ENDPOINT="${OBJECTSTORE_ENDPOINT:-${AWS_S3_ENDPOINT:-}}"
export OBJECTSTORE_BUCKET="${OBJECTSTORE_BUCKET:-${AWS_S3_BUCKET:-}}"
export OBJECTSTORE_ACCESS_KEY="${OBJECTSTORE_ACCESS_KEY:-${AWS_ACCESS_KEY_ID:-}}"
export OBJECTSTORE_SECRET_KEY="${OBJECTSTORE_SECRET_KEY:-${AWS_SECRET_ACCESS_KEY:-}}"

# Generate config from template with secrets injected
if [ -f "$TEMPLATE" ]; then
  sed \
    -e "s|__OPENROUTER_API_KEY__|${OPENROUTER_API_KEY:-}|g" \
    -e "s|__CLIPROXY_MANAGEMENT_PASSWORD__|${CLIPROXY_MANAGEMENT_PASSWORD:-}|g" \
    -e "s|__ZAI_API_KEY__|${ZAI_API_KEY:-}|g" \
    "$TEMPLATE" >"$CONFIG"
  # Also copy to objectstore config location (cliproxyapi uses this for persistence)
  mkdir -p "$CONFIG_DIR/objectstore/config"
  cp "$CONFIG" "$CONFIG_DIR/objectstore/config/config.yaml"

  # Upload config to S3 to ensure backup is always correct
  # This prevents corrupted configs from persisting across restarts
  if [ -n "${OBJECTSTORE_ENDPOINT:-}" ] && [ -n "${OBJECTSTORE_ACCESS_KEY:-}" ]; then
    echo "Uploading config to S3 backup..." >&2
    AWS_ACCESS_KEY_ID="${OBJECTSTORE_ACCESS_KEY}" \
      AWS_SECRET_ACCESS_KEY="${OBJECTSTORE_SECRET_KEY}" \
      aws s3 cp \
      --endpoint-url="${OBJECTSTORE_ENDPOINT}" \
      --no-progress \
      "$CONFIG" \
      "s3://cliproxyapi/config/config.yaml" 2>/dev/null || echo "⚠️  Config backup failed (continuing anyway)" >&2
  fi
fi

# Change to config dir so logs are created there
cd "$CONFIG_DIR"

# Find and exec cliproxyapi with config file
if [ -x /opt/homebrew/bin/cliproxyapi ]; then
  exec /opt/homebrew/bin/cliproxyapi -config "$CONFIG" "$@"
elif [ -x /usr/local/bin/cliproxyapi ]; then
  exec /usr/local/bin/cliproxyapi -config "$CONFIG" "$@"
else
  echo 'cliproxyapi binary not found; install it with "brew install cliproxyapi"' >&2
  exit 1
fi
