#!/usr/bin/env bash
# OpenClaw config hydration with runtime secret injection
# Mode is set by nix: "gateway" for Kyber, "client" for macOS
# shellcheck source=/dev/null
set -euo pipefail

MODE="@mode@"
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

# Load gateway token (required for both modes)
GATEWAY_TOKEN="${OPENCLAW_GATEWAY_TOKEN:-${GATEWAY_TOKEN:-$(read_secret "${SECRETS_DIR}/gateway-token")}}"

if [ -z "${GATEWAY_TOKEN}" ]; then
  echo "Warning: OPENCLAW_GATEWAY_TOKEN not set, skipping OpenClaw hydration" >&2
  exit 0
fi

mkdir -p "$STATE_DIR"

if [ "$MODE" = "gateway" ]; then
  # Gateway mode (Kyber): hydrate full template and start gateway
  CLIPROXY_API_KEY="${OPENCLAW_CLIPROXY_API_KEY:-${CLIPROXY_API_KEY:-$(read_secret "${SECRETS_DIR}/cliproxy-key")}}"
  TELEGRAM_TOKEN="${OPENCLAW_TELEGRAM_TOKEN:-${TELEGRAM_TOKEN:-$(read_secret "${SECRETS_DIR}/telegram-token")}}"
  ANTHROPIC_API_KEY="${OPENCLAW_ANTHROPIC_API_KEY:-${ANTHROPIC_API_KEY:-$(read_secret "${SECRETS_DIR}/anthropic-key")}}"
  CHROMIUM_PATH="@chromium@/bin/chromium"

  @sed@ \
    -e "s|__CLIPROXY_API_KEY__|${CLIPROXY_API_KEY}|g" \
    -e "s|__TELEGRAM_TOKEN__|${TELEGRAM_TOKEN}|g" \
    -e "s|__GATEWAY_TOKEN__|${GATEWAY_TOKEN}|g" \
    -e "s|__CHROMIUM_PATH__|${CHROMIUM_PATH}|g" \
    -e "s|__HOME__|${HOME}|g" \
    "$TEMPLATE" >"$CONFIG"

  echo "Generated openclaw gateway config at $CONFIG" >&2

  if [ -n "$ANTHROPIC_API_KEY" ]; then
    export ANTHROPIC_API_KEY
  fi

  exec @openclaw@/bin/openclaw gateway --port 18789 "$@"

else
  # Client mode (macOS): generate remote config with gateway token
  cat >"$CONFIG" <<EOF
{
  "gateway": {
    "mode": "remote",
    "remote": {
      "transport": "direct",
      "url": "wss://kyber.tail950b36.ts.net",
      "password": "${GATEWAY_TOKEN}"
    }
  }
}
EOF

  echo "Generated openclaw client config at $CONFIG" >&2
fi
