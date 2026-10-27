#!/usr/bin/env sh
# Single .env parser for every shell and for the GUI exporter: each consumer only
# applies the KEY=VALUE lines printed here, so the parsing rules cannot drift.
set -eu

env_file=""
for candidate in "${DOTFILES_ENV_FILE:-}" "$HOME/dotfiles/.env" "$HOME/.env"; do
  [ -n "$candidate" ] || continue
  if [ -f "$candidate" ]; then
    env_file="$candidate"
    break
  fi
done

[ -n "$env_file" ] || exit 0

# `|| [ -n "$line" ]` keeps a trailing line that has no newline.
while IFS= read -r line || [ -n "$line" ]; do
  line="${line#"${line%%[![:space:]]*}"}"
  line="${line%"${line##*[![:space:]]}"}"

  case "$line" in
  '' | '#'*) continue ;;
  export[[:space:]]*)
    line="${line#export}"
    line="${line#"${line%%[![:space:]]*}"}"
    ;;
  esac

  case "$line" in
  *=*) ;;
  *) continue ;;
  esac

  key="${line%%=*}"
  value="${line#*=}"

  key="${key%"${key##*[![:space:]]}"}"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"

  case "$key" in
  '' | [0-9]* | *[!A-Za-z0-9_]*) continue ;;
  esac

  case "$value" in
  \"*\") value="${value%\"}" && value="${value#\"}" ;;
  \'*\') value="${value%\'}" && value="${value#\'}" ;;
  esac

  printf '%s=%s\n' "$key" "$value"
done <"$env_file"

# Printed last so they override: while iron-proxy listens, agent shells get a
# placeholder that the proxy swaps for the real secret on the wire. Without
# env-ready the real values stay, so a dead proxy never breaks auth. Callers
# without proxy env (systemd user services) would send the placeholder
# straight upstream, so they keep the real values too.
swap_keys="${IRON_PROXY_SWAP_DIR:-/var/lib/iron-proxy-secrets}/swap-keys"
case "${HTTPS_PROXY:-${https_proxy:-}}" in
http://127.0.0.1:*) proxied=1 ;;
*) proxied="" ;;
esac
if [ -n "$proxied" ] && [ -e "${IRON_PROXY_STATE_DIR:-/var/lib/iron-proxy}/env-ready" ] && [ -r "$swap_keys" ]; then
  while IFS= read -r key || [ -n "$key" ]; do
    case "$key" in
    '' | [0-9]* | *[!A-Za-z0-9_]*) continue ;;
    esac
    printf '%s=iron-proxy-swap-%s\n' "$key" "$key"
  done <"$swap_keys"
fi
