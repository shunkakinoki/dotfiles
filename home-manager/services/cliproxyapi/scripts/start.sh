#!/usr/bin/env bash
set -euo pipefail

CONFIG_DIR="${HOME}/.cli-proxy-api"
TEMPLATE="$CONFIG_DIR/config.template.yaml"
CONFIG="$CONFIG_DIR/config.yaml"
ENV_FILE="${HOME}/dotfiles/.env"

if [ -f "$ENV_FILE" ]; then
  set -a
  . "$ENV_FILE"
  set +a
fi

strip_quotes() { local v="$1"; v="${v%\"}"; v="${v#\"}"; printf '%s' "$v"; }
export OBJECTSTORE_ENDPOINT="$(strip_quotes "${OBJECTSTORE_ENDPOINT:-}")"
export OBJECTSTORE_BUCKET="$(strip_quotes "${OBJECTSTORE_BUCKET:-cliproxyapi}")"
export OBJECTSTORE_ACCESS_KEY="$(strip_quotes "${OBJECTSTORE_ACCESS_KEY:-}")"
export OBJECTSTORE_SECRET_KEY="$(strip_quotes "${OBJECTSTORE_SECRET_KEY:-}")"
export MANAGEMENT_PASSWORD="${CLIPROXY_MANAGEMENT_PASSWORD:-}"

# Generate config from template
if [ -f "$TEMPLATE" ]; then
  @sed@ \
    -e "s|__OPENROUTER_API_KEY__|${OPENROUTER_API_KEY:-}|g" \
    -e "s|__CLIPROXY_MANAGEMENT_PASSWORD__|${CLIPROXY_MANAGEMENT_PASSWORD:-}|g" \
    -e "s|__ZAI_API_KEY__|${ZAI_API_KEY:-}|g" \
    -e "s|__AMP_UPSTREAM_API_KEY__|${AMP_UPSTREAM_API_KEY:-}|g" \
    "$TEMPLATE" > "$CONFIG"

  if [ "$(uname)" = "Linux" ] && [ -n "${CLIPROXY_API_KEY:-}" ]; then
    @sed@ -i \
      -e "s|^# api-keys:|api-keys:|" \
      -e "s|^#   - \"__CLIPROXY_API_KEY__\"|  - \"${CLIPROXY_API_KEY}\"|" \
      "$CONFIG"
  fi
fi

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
