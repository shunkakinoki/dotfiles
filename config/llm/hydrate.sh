#!/usr/bin/env bash
# Synchronize CLIPROXY_API_KEY into LLM's cliproxyapi key alias.
# shellcheck source=/dev/null
set -euo pipefail

ENV_FILE="${HOME}/dotfiles/.env"
CLIPROXY_CONFIG="${CLIPROXY_CONFIG_PATH:-${HOME}/.cli-proxy-api/config.yaml}"
CLIPROXY_KEY_FILE="${HOME}/.config/openclaw/cliproxy-key"
CLIPROXY_API_KEY="${CLIPROXY_API_KEY:-}"

if [ -z "$CLIPROXY_API_KEY" ] && [ -f "$ENV_FILE" ]; then
  set -a
  . "$ENV_FILE"
  set +a
fi

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

if [ -z "$CLIPROXY_API_KEY" ]; then
  CLIPROXY_API_KEY="$(read_cliproxy_api_key_from_config "$CLIPROXY_CONFIG")"
fi
if [ -z "$CLIPROXY_API_KEY" ] && [ -f "$CLIPROXY_KEY_FILE" ]; then
  CLIPROXY_API_KEY="$(tr -d '\n\r' <"$CLIPROXY_KEY_FILE")"
fi
if [ -z "$CLIPROXY_API_KEY" ]; then
  echo "Warning: CLIPROXY_API_KEY not found, skipping LLM key hydration" >&2
  exit 0
fi
export CLIPROXY_API_KEY

case "$(uname -s)" in
Darwin) LLM_DIR="${LLM_USER_PATH:-${HOME}/Library/Application Support/io.datasette.llm}" ;;
Linux) LLM_DIR="${LLM_USER_PATH:-${XDG_CONFIG_HOME:-${HOME}/.config}/io.datasette.llm}" ;;
*)
  echo "llm hydrate: unsupported OS $(uname -s)" >&2
  exit 0
  ;;
esac

mkdir -p "$LLM_DIR"
KEYS_FILE="${LLM_DIR}/keys.json"
TMP="$(mktemp "${LLM_DIR}/.keys.json.XXXXXX")"
trap 'rm -f "$TMP"' EXIT

if [ -f "$KEYS_FILE" ]; then
  if ! @jq@ empty "$KEYS_FILE" >/dev/null 2>&1; then
    echo "Warning: LLM keys file is malformed, leaving it unchanged: $KEYS_FILE" >&2
    exit 0
  fi
  @jq@ '. + {"cliproxyapi": env.CLIPROXY_API_KEY}' "$KEYS_FILE" >"$TMP"
else
  @jq@ -n '{"// Note": "This file stores secret API credentials. Do not share!", "cliproxyapi": env.CLIPROXY_API_KEY}' >"$TMP"
fi

chmod 600 "$TMP"
mv -f "$TMP" "$KEYS_FILE"
trap - EXIT
echo "Hydrated LLM cliproxyapi key from CLIPROXY_API_KEY" >&2
