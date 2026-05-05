#!/usr/bin/env bash
# OpenClaw config hydration with runtime secret injection
# Mode is set by nix: "gateway" for Kyber, "client" for macOS
# shellcheck source=/dev/null
set -euo pipefail

MODE="@mode@"
STATE_DIR="${OPENCLAW_STATE_DIR:-${HOME}/.openclaw}"
mkdir -p "$STATE_DIR"
CONFIG="${OPENCLAW_CONFIG_PATH:-${STATE_DIR}/openclaw.json}"
TEMPLATE="@template@"
SOUL_SOURCE="@soul@"
SECRETS_DIR="${HOME}/.config/openclaw"
CLIPROXY_CONFIG="${OPENCLAW_CLIPROXY_CONFIG_PATH:-${HOME}/.cli-proxy-api/config.yaml}"
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

read_cliproxy_api_key_from_config() {
  local config_file="$1"
  [ -f "$config_file" ] || return 0

  # shellcheck disable=SC2016
  @awk@ '
    /^api-keys:/ { in_api_keys = 1; next }
    in_api_keys && /^  - / {
      value = $0
      sub(/^  - "/, "", value)
      sub(/"$/, "", value)
      print value
      exit
    }
    in_api_keys && /^[^[:space:]]/ { exit }
  ' "$config_file"
}

# Load gateway token (required for both modes)
GATEWAY_TOKEN="${OPENCLAW_GATEWAY_TOKEN:-${GATEWAY_TOKEN:-$(read_secret "${SECRETS_DIR}/gateway-token")}}"

if [ -z "${GATEWAY_TOKEN}" ]; then
  echo "Warning: OPENCLAW_GATEWAY_TOKEN not set, skipping OpenClaw hydration" >&2
  exit 0
fi

mkdir -p "$STATE_DIR"

# Sync SOUL.md from dotfiles root (single source of truth)
install -m 600 "$SOUL_SOURCE" "${STATE_DIR}/SOUL.md"

if [ "$MODE" = "gateway" ]; then
  # Gateway mode (Kyber): hydrate full template and start gateway
  cliproxy_api_key_from_env="${CLIPROXY_API_KEY:-}"
  CLIPROXY_API_KEY="${OPENCLAW_CLIPROXY_API_KEY:-}"
  if [ -z "$CLIPROXY_API_KEY" ]; then
    CLIPROXY_API_KEY="$(read_cliproxy_api_key_from_config "$CLIPROXY_CONFIG")"
  fi
  if [ -z "$CLIPROXY_API_KEY" ]; then
    CLIPROXY_API_KEY="$cliproxy_api_key_from_env"
  fi
  if [ -z "$CLIPROXY_API_KEY" ]; then
    CLIPROXY_API_KEY="$(read_secret "${SECRETS_DIR}/cliproxy-key")"
  fi
  TELEGRAM_TOKEN="${OPENCLAW_TELEGRAM_TOKEN:-${TELEGRAM_TOKEN:-$(read_secret "${SECRETS_DIR}/telegram-token")}}"
  WHATSAPP_ALLOW_FROM="${OPENCLAW_WHATSAPP_ALLOW_FROM:-${WHATSAPP_ALLOW_FROM:-$(read_secret "${SECRETS_DIR}/whatsapp-allow-from")}}"
  ANTHROPIC_API_KEY="${OPENCLAW_ANTHROPIC_API_KEY:-${ANTHROPIC_API_KEY:-$(read_secret "${SECRETS_DIR}/anthropic-key")}}"
  HOOKS_TOKEN="${OPENCLAW_HOOKS_TOKEN:-${HOOKS_TOKEN:-$(read_secret "${SECRETS_DIR}/hooks-token")}}"
  CHROMIUM_PATH="@chromium@/bin/chromium"

  # Resolve Alloy OTLP ClusterIP for local telemetry export
  OTEL_ENDPOINT="http://$(@kubectl@ get svc alloy -n alloy -o jsonpath='{.spec.clusterIP}' 2>/dev/null || echo localhost):4318"

  @sed@ \
    -e "s|__CLIPROXY_API_KEY__|${CLIPROXY_API_KEY}|g" \
    -e "s|__TELEGRAM_TOKEN__|${TELEGRAM_TOKEN}|g" \
    -e "s|__WHATSAPP_ALLOW_FROM__|${WHATSAPP_ALLOW_FROM}|g" \
    -e "s|__HOOKS_TOKEN__|${HOOKS_TOKEN}|g" \
    -e "s|__GATEWAY_TOKEN__|${GATEWAY_TOKEN}|g" \
    -e "s|__CHROMIUM_PATH__|${CHROMIUM_PATH}|g" \
    -e "s|__OTEL_ENDPOINT__|${OTEL_ENDPOINT}|g" \
    -e "s|__HOME__|${HOME}|g" \
    "$TEMPLATE" >"$CONFIG"
  chmod 600 "$CONFIG"

  echo "Generated openclaw gateway config at $CONFIG" >&2

else
  # Client mode (macOS): connect through kyber's Tailscale Serve endpoint
  cat >"$CONFIG" <<EOF
{
  "gateway": {
    "mode": "remote",
    "remote": {
      "transport": "direct",
      "url": "wss://kyber.tail950b36.ts.net",
      "token": "${GATEWAY_TOKEN}"
    }
  }
}
EOF
  chmod 600 "$CONFIG"

  echo "Generated openclaw client config at $CONFIG" >&2
fi
