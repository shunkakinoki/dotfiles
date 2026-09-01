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
SOUL_SOURCE="@soul@"
TRACES_PLUGIN_MANIFEST="@tracesPluginManifest@"
TRACES_PLUGIN_MODULE="@tracesPluginModule@"
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
WEBHOOK_SECRET="${HERMES_WEBHOOK_SECRET:-$(read_secret "${SECRETS_DIR}/webhook-secret")}"
VERCEL_TOKEN="${VERCEL_TOKEN:-$(read_secret "${SECRETS_DIR}/vercel-token")}"
VERCEL_TEAM_ID="${VERCEL_TEAM_ID:-$(read_secret "${SECRETS_DIR}/vercel-team-id")}"

if [ -z "${GATEWAY_TOKEN}" ]; then
  echo "Warning: HERMES_GATEWAY_TOKEN not set, skipping Hermes hydration" >&2
  exit 0
fi

# Hydrate config.yaml
@sed@ \
  -e "s|__CLIPROXY_API_KEY__|${CLIPROXY_API_KEY}|g" \
  -e "s|__WEBHOOK_SECRET__|${WEBHOOK_SECRET}|g" \
  "$CONFIG_TEMPLATE" >"${STATE_DIR}/config.yaml"
chmod 600 "${STATE_DIR}/config.yaml"

# Hydrate .env
@sed@ \
  -e "s|__TELEGRAM_TOKEN__|${TELEGRAM_TOKEN}|g" \
  -e "s|__WHATSAPP_ALLOW_FROM__|${WHATSAPP_ALLOW_FROM}|g" \
  -e "s|__GATEWAY_TOKEN__|${GATEWAY_TOKEN}|g" \
  -e "s|__CLIPROXY_API_KEY__|${CLIPROXY_API_KEY}|g" \
  -e "s|__VERCEL_TOKEN__|${VERCEL_TOKEN}|g" \
  -e "s|__VERCEL_TEAM_ID__|${VERCEL_TEAM_ID}|g" \
  "$ENV_TEMPLATE" >"${STATE_DIR}/.env"
chmod 600 "${STATE_DIR}/.env"

# Sync SOUL.md from dotfiles root (single source of truth)
install -m 600 "$SOUL_SOURCE" "${STATE_DIR}/SOUL.md"

# Install the Traces plugin. Hermes only discovers plugin directories that
# carry a manifest, so the traces-generated flat traces_hook.py is inert.
install -d -m 700 "${STATE_DIR}/plugins/traces"
install -m 600 "$TRACES_PLUGIN_MANIFEST" "${STATE_DIR}/plugins/traces/plugin.yaml"
install -m 600 "$TRACES_PLUGIN_MODULE" "${STATE_DIR}/plugins/traces/__init__.py"
rm -f "${STATE_DIR}/plugins/traces_hook.py"

# traces refuses to run outside a git repository and resolves the destination
# namespace from the working directory, so the plugin needs a stable repo root.
install -d -m 700 "${STATE_DIR}/workspace"
if [ ! -d "${STATE_DIR}/workspace/.git" ]; then
  @git@ -C "${STATE_DIR}/workspace" init -q
fi

echo "Generated hermes ${MODE} config at ${STATE_DIR}" >&2
