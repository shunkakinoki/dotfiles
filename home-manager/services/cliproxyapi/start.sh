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

# Generate config from template with secrets injected
if [ -f "$TEMPLATE" ]; then
  sed -e "s|__OPENROUTER_API_KEY__|${OPENROUTER_API_KEY:-}|g" \
      -e "s|__CLIPROXY_MANAGEMENT_PASSWORD__|${CLIPROXY_MANAGEMENT_PASSWORD:-}|g" \
      "$TEMPLATE" >"$CONFIG"
fi

# Change to config dir so logs are created there
cd "$CONFIG_DIR"

# Export S3-compatible object storage env vars (for R2 or any S3-compatible storage)
export OBJECTSTORE_ENDPOINT="${OBJECTSTORE_ENDPOINT:-${AWS_S3_ENDPOINT:-}}"
export OBJECTSTORE_BUCKET="${OBJECTSTORE_BUCKET:-${AWS_S3_BUCKET:-}}"
export OBJECTSTORE_ACCESS_KEY="${OBJECTSTORE_ACCESS_KEY:-${AWS_ACCESS_KEY_ID:-}}"
export OBJECTSTORE_SECRET_KEY="${OBJECTSTORE_SECRET_KEY:-${AWS_SECRET_ACCESS_KEY:-}}"

# Find and exec cliproxyapi with config file
if [ -x /opt/homebrew/bin/cliproxyapi ]; then
  exec /opt/homebrew/bin/cliproxyapi -config "$CONFIG" "$@"
elif [ -x /usr/local/bin/cliproxyapi ]; then
  exec /usr/local/bin/cliproxyapi -config "$CONFIG" "$@"
else
  echo 'cliproxyapi binary not found; install it with "brew install cliproxyapi"' >&2
  exit 1
fi
