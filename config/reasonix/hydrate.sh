#!/usr/bin/env bash
set -euo pipefail

STATE_DIR="${HOME}/.reasonix"
CONFIG_FILE="${STATE_DIR}/config.toml"
KEY_FILE="${STATE_DIR}/.env"
TEMPLATE="@template@"
DOTFILES_ENV="${HOME}/dotfiles/.env"
CLIPROXY_CONFIG="${HOME}/.cli-proxy-api/config.yaml"

mkdir -p "$STATE_DIR"
chmod 700 "$STATE_DIR"

if [ -f "$DOTFILES_ENV" ]; then
  set -a
  # shellcheck source=/dev/null
  . "$DOTFILES_ENV"
  set +a
fi

CLIPROXY_API_KEY="${CLIPROXY_API_KEY:-}"
if [ -z "$CLIPROXY_API_KEY" ] && [ -f "$CLIPROXY_CONFIG" ]; then
  # shellcheck disable=SC2016
  CLIPROXY_API_KEY="$(@awk@ '
    /^api-keys:/ { in_api_keys = 1; next }
    in_api_keys && /^  - / {
      value = $0
      sub(/^  - "/, "", value)
      sub(/"$/, "", value)
      print value
      exit
    }
    in_api_keys && /^[^[:space:]]/ { exit }
  ' "$CLIPROXY_CONFIG")"
fi

# Reasonix resolves api_key_env only from its own .env, never the process
# environment, so the key has to be mirrored there.
if [ -n "$CLIPROXY_API_KEY" ]; then
  tmp="$(mktemp "${STATE_DIR}/.env.XXXXXX")"
  trap 'rm -f "$tmp"' EXIT
  if [ -f "$KEY_FILE" ]; then
    grep -v '^CLIPROXY_API_KEY=' "$KEY_FILE" >"$tmp" || true
  fi
  printf 'CLIPROXY_API_KEY=%s\n' "$CLIPROXY_API_KEY" >>"$tmp"
  if [ -f "$KEY_FILE" ] && cmp -s "$tmp" "$KEY_FILE"; then
    rm -f "$tmp"
  else
    chmod 600 "$tmp"
    mv -f "$tmp" "$KEY_FILE"
  fi
  trap - EXIT
else
  echo "Warning: CLIPROXY_API_KEY not found, Reasonix CLIProxy provider will lack a key" >&2
fi

if [ ! -f "$CONFIG_FILE" ]; then
  install -m 600 "$TEMPLATE" "$CONFIG_FILE"
  echo "Seeded Reasonix config at $CONFIG_FILE" >&2
  exit 0
fi

if ! @tomlq@ '.' "$CONFIG_FILE" >/dev/null 2>&1; then
  echo "Warning: Reasonix config is malformed, leaving it unchanged: $CONFIG_FILE" >&2
  exit 0
fi

# Managed providers replace same-named entries; everything else stays user-owned.
# shellcheck disable=SC2016
MERGE='.[0] as $c | .[1] as $t | ($t.providers | map(.name)) as $managed
  | $c
  | .default_model = $t.default_model
  | .providers = ([($c.providers // [])[] | select(.name as $n | $managed | index($n) | not)] + $t.providers)'

# Rewriting drops Reasonix's inline comments, so only write on drift.
current="$(@tomlq@ -S -c '.' "$CONFIG_FILE")"
merged="$(@tomlq@ -S -c -s "$MERGE" "$CONFIG_FILE" "$TEMPLATE")"
if [ "$current" = "$merged" ]; then
  exit 0
fi

tmp="$(mktemp "${STATE_DIR}/.config.toml.XXXXXX")"
trap 'rm -f "$tmp"' EXIT
@tomlq@ -t -s "$MERGE" "$CONFIG_FILE" "$TEMPLATE" >"$tmp"
chmod 600 "$tmp"
mv -f "$tmp" "$CONFIG_FILE"
trap - EXIT
echo "Hydrated Reasonix config at $CONFIG_FILE" >&2
