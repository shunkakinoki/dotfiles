#!/usr/bin/env bash
# OpenClaw gateway start script with runtime secret injection
# shellcheck source=/dev/null
set -euo pipefail

STATE_DIR="${OPENCLAW_STATE_DIR:-${HOME}/.openclaw}"
CONFIG="${OPENCLAW_CONFIG_PATH:-${STATE_DIR}/openclaw.json}"
TEMPLATE="@template@"
SECRETS_DIR="${HOME}/.config/openclaw"
ENV_FILE="${HOME}/dotfiles/.env"

# Source .env if it exists
if [ -f "$ENV_FILE" ]; then
  set -a
  . "$ENV_FILE"
  set +a
fi

# Read secret from file, stripping whitespace
read_secret() {
  local file
  for file in "$@"; do
    if [ -f "$file" ]; then
      tr -d '\n\r' <"$file"
      return
    fi
  done
  echo ""
}

# Load secrets from files or environment
CLIPROXY_API_KEY="${OPENCLAW_CLIPROXY_API_KEY:-${CLIPROXY_API_KEY:-$(read_secret "${SECRETS_DIR}/cliproxy-key")}}"
TELEGRAM_TOKEN="${OPENCLAW_TELEGRAM_TOKEN:-${TELEGRAM_TOKEN:-$(read_secret "${SECRETS_DIR}/telegram-token")}}"
GATEWAY_TOKEN="${OPENCLAW_GATEWAY_TOKEN:-${GATEWAY_TOKEN:-$(read_secret "${SECRETS_DIR}/gateway-token")}}"
ANTHROPIC_API_KEY="${OPENCLAW_ANTHROPIC_API_KEY:-${ANTHROPIC_API_KEY:-$(read_secret "${SECRETS_DIR}/anthropic-key")}}"

# Chromium path (injected by nix)
CHROMIUM_PATH="@chromium@/bin/chromium"

# Create state directory if needed
mkdir -p "$STATE_DIR"

# Generate config from template with secret substitution
@sed@ \
  -e "s|__CLIPROXY_API_KEY__|${CLIPROXY_API_KEY}|g" \
  -e "s|__TELEGRAM_TOKEN__|${TELEGRAM_TOKEN}|g" \
  -e "s|__GATEWAY_TOKEN__|${GATEWAY_TOKEN}|g" \
  -e "s|__CHROMIUM_PATH__|${CHROMIUM_PATH}|g" \
  -e "s|__HOME__|${HOME}|g" \
  "$TEMPLATE" >"$CONFIG"

echo "Generated openclaw config at $CONFIG" >&2

# Export Anthropic API key for OpenClaw
if [ -n "$ANTHROPIC_API_KEY" ]; then
  export ANTHROPIC_API_KEY
fi

# Start OpenClaw gateway
exec @openclaw@/bin/openclaw gateway --port 18789 "$@"
