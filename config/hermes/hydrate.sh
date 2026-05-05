#!/usr/bin/env bash
# Hermes config hydration with runtime secret injection
# Mode is set by nix: "gateway" for Kyber, "client" for macOS
# shellcheck source=/dev/null
set -euo pipefail

MODE="@mode@"
STATE_DIR="${HOME}/.hermes"
mkdir -p "$STATE_DIR"
CONFIG_TEMPLATE="@configTemplate@"
ENV_TEMPLATE="@envTemplate@"
SECRETS_DIR="${HOME}/.config/hermes"
CLIPROXY_CONFIG="${HOME}/.cli-proxy-api/config.yaml"
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

# Resolve secrets
CLIPROXY_API_KEY="${CLIPROXY_API_KEY:-}"
if [ -z "$CLIPROXY_API_KEY" ]; then
  CLIPROXY_API_KEY="$(read_cliproxy_api_key_from_config "$CLIPROXY_CONFIG")"
fi
if [ -z "$CLIPROXY_API_KEY" ]; then
  CLIPROXY_API_KEY="$(read_secret "${SECRETS_DIR}/cliproxy-key")"
fi

TELEGRAM_TOKEN="${HERMES_TELEGRAM_TOKEN:-${TELEGRAM_TOKEN:-$(read_secret "${SECRETS_DIR}/telegram-token")}}"
GATEWAY_TOKEN="${HERMES_GATEWAY_TOKEN:-${GATEWAY_TOKEN:-$(read_secret "${SECRETS_DIR}/gateway-token")}}"
WHATSAPP_ALLOW_FROM="${WHATSAPP_ALLOW_FROM:-$(read_secret "${SECRETS_DIR}/whatsapp-allow-from")}"

if [ -z "${GATEWAY_TOKEN}" ]; then
  echo "Warning: HERMES_GATEWAY_TOKEN not set, skipping Hermes hydration" >&2
  exit 0
fi

# Hydrate config.yaml
@sed@ \
  -e "s|__CLIPROXY_API_KEY__|${CLIPROXY_API_KEY}|g" \
  "$CONFIG_TEMPLATE" >"${STATE_DIR}/config.yaml"
chmod 600 "${STATE_DIR}/config.yaml"

# Hydrate .env
@sed@ \
  -e "s|__TELEGRAM_TOKEN__|${TELEGRAM_TOKEN}|g" \
  -e "s|__WHATSAPP_ALLOW_FROM__|${WHATSAPP_ALLOW_FROM}|g" \
  -e "s|__GATEWAY_TOKEN__|${GATEWAY_TOKEN}|g" \
  -e "s|__CLIPROXY_API_KEY__|${CLIPROXY_API_KEY}|g" \
  "$ENV_TEMPLATE" >"${STATE_DIR}/.env"
chmod 600 "${STATE_DIR}/.env"

echo "Generated hermes ${MODE} config at ${STATE_DIR}" >&2
