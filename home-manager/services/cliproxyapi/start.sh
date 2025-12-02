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

# Generate config from template with secrets injected
if [ -f "$TEMPLATE" ]; then
  sed "s|__OPENROUTER_API_KEY__|${OPENROUTER_API_KEY:-}|g" "$TEMPLATE" >"$CONFIG"
fi

# Find and exec cliproxyapi with config file
if [ -x /opt/homebrew/bin/cliproxyapi ]; then
  exec /opt/homebrew/bin/cliproxyapi -config "$CONFIG" "$@"
elif [ -x /usr/local/bin/cliproxyapi ]; then
  exec /usr/local/bin/cliproxyapi -config "$CONFIG" "$@"
else
  echo 'cliproxyapi binary not found; install it with "brew install cliproxyapi"' >&2
  exit 1
fi
