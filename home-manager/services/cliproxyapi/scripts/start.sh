#!/usr/bin/env bash

set -euo pipefail

CONFIG_DIR="$HOME/.cli-proxy-api"
TEMPLATE="$CONFIG_DIR/config.template.yaml"
CONFIG="$CONFIG_DIR/config.yaml"
AUTH_DIR="$CONFIG_DIR/objectstore/auths"
# Use explicit path since $HOME may not be set correctly in launchd context
ENV_FILE="${HOME:-/Users/shunkakinoki}/dotfiles/.env"

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

# CRITICAL: Pull auth files from R2 before starting cliproxyapi
# This ensures all auth files (including codex-*) are available when the service starts
# CLIProxyAPI expects auth files in {auth-dir}/auths/ so we sync directly there
CLIPROXY_AUTH_DIR="$CONFIG_DIR/auths"
if [ -n "${OBJECTSTORE_ENDPOINT:-}" ] && [ -n "${OBJECTSTORE_ACCESS_KEY:-}" ]; then
  echo "Syncing auth files from R2..." >&2
  mkdir -p "$CLIPROXY_AUTH_DIR"

  # Pull from both active and backup locations to ensure we have all files
  AWS_ACCESS_KEY_ID="${OBJECTSTORE_ACCESS_KEY}" \
    AWS_SECRET_ACCESS_KEY="${OBJECTSTORE_SECRET_KEY}" \
    @aws@ s3 sync \
    --endpoint-url="${OBJECTSTORE_ENDPOINT}" \
    --no-progress \
    "s3://cliproxyapi/auths/" \
    "$CLIPROXY_AUTH_DIR/" 2>/dev/null && echo "✅ Pulled from R2 auths/" >&2 || true

  AWS_ACCESS_KEY_ID="${OBJECTSTORE_ACCESS_KEY}" \
    AWS_SECRET_ACCESS_KEY="${OBJECTSTORE_SECRET_KEY}" \
    @aws@ s3 sync \
    --endpoint-url="${OBJECTSTORE_ENDPOINT}" \
    --no-progress \
    "s3://cliproxyapi/backup/auths/" \
    "$CLIPROXY_AUTH_DIR/" 2>/dev/null && echo "✅ Pulled from R2 backup/auths/" >&2 || true

  # Bootstrap from git-tracked dotfiles if empty
  if [ ! -d "$CLIPROXY_AUTH_DIR" ] || [ -z "$(ls -A "$CLIPROXY_AUTH_DIR" 2>/dev/null)" ]; then
    if [ -d "$HOME/dotfiles/objectstore/auths" ] && [ -n "$(ls -A "$HOME/dotfiles/objectstore/auths" 2>/dev/null)" ]; then
      @rsync@ -a "$HOME/dotfiles/objectstore/auths/" "$CLIPROXY_AUTH_DIR/"
      echo "✅ Bootstrapped from dotfiles (objectstore was empty)" >&2
    fi
  fi

  # Also keep objectstore/auths/ in sync for legacy compatibility
  mkdir -p "$AUTH_DIR"
  @rsync@ -a "$CLIPROXY_AUTH_DIR/" "$AUTH_DIR/"
else
  echo "⚠️  Skipping auth sync: OBJECTSTORE credentials not set" >&2
fi

# Generate config from template with secrets injected
if [ -f "$TEMPLATE" ]; then
  @sed@ \
    -e "s|__OPENROUTER_API_KEY__|${OPENROUTER_API_KEY:-}|g" \
    -e "s|__CLIPROXY_MANAGEMENT_PASSWORD__|${CLIPROXY_MANAGEMENT_PASSWORD:-}|g" \
    -e "s|__ZAI_API_KEY__|${ZAI_API_KEY:-}|g" \
    -e "s|__AMP_UPSTREAM_API_KEY__|${AMP_UPSTREAM_API_KEY:-}|g" \
    "$TEMPLATE" >"$CONFIG"
  # Also copy to objectstore config location (cliproxyapi uses this for persistence)
  mkdir -p "$CONFIG_DIR/objectstore/config"
  cp "$CONFIG" "$CONFIG_DIR/objectstore/config/config.yaml"

  # Upload config to S3 to ensure backup is always correct
  # This prevents corrupted configs from persisting across restarts
  if [ -n "${OBJECTSTORE_ENDPOINT:-}" ] && [ -n "${OBJECTSTORE_ACCESS_KEY:-}" ]; then
    echo "Uploading config to S3 backup..." >&2
    if AWS_ACCESS_KEY_ID="${OBJECTSTORE_ACCESS_KEY}" \
      AWS_SECRET_ACCESS_KEY="${OBJECTSTORE_SECRET_KEY}" \
      @aws@ s3 cp \
      --endpoint-url="${OBJECTSTORE_ENDPOINT}" \
      --no-progress \
      "$CONFIG" \
      "s3://cliproxyapi/config/config.yaml" 2>&1; then
      echo "✅ Config backup uploaded" >&2
    else
      echo "⚠️  Config backup failed (continuing anyway)" >&2
    fi
  else
    echo "⚠️  S3 config backup skipped: missing credentials" >&2
  fi
fi

# Change to config dir so logs are created there
cd "$CONFIG_DIR"

# On Linux, prefer Docker for easy upgrades
if [ "$(uname)" = "Linux" ] && command -v docker >/dev/null 2>&1; then
  # Stop any existing container
  docker rm -f cliproxyapi 2>/dev/null || true

  # Create logs directory if it doesn't exist
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

# macOS: use Homebrew binary
if [ -x /opt/homebrew/bin/cliproxyapi ]; then
  exec /opt/homebrew/bin/cliproxyapi -config "$CONFIG" "$@"
elif [ -x /usr/local/bin/cliproxyapi ]; then
  exec /usr/local/bin/cliproxyapi -config "$CONFIG" "$@"
else
  echo 'cliproxyapi not found' >&2
  echo 'Linux: Docker should be available' >&2
  echo 'macOS: brew install cliproxyapi' >&2
  exit 1
fi
