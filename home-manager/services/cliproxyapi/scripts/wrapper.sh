#!/usr/bin/env bash
# shellcheck source=/dev/null
set -euo pipefail

ENV_FILE="${HOME}/dotfiles/.env"
if [ -f "$ENV_FILE" ]; then
  set -a
  . "$ENV_FILE"
  set +a
fi

strip_quotes() {
  local v="$1"
  v="${v%\"}"
  v="${v#\"}"
  printf '%s' "$v"
}
OBJECTSTORE_ENDPOINT="$(strip_quotes "${OBJECTSTORE_ENDPOINT:-}")"
OBJECTSTORE_BUCKET="$(strip_quotes "${OBJECTSTORE_BUCKET:-cliproxyapi}")"
OBJECTSTORE_ACCESS_KEY="$(strip_quotes "${OBJECTSTORE_ACCESS_KEY:-}")"
OBJECTSTORE_SECRET_KEY="$(strip_quotes "${OBJECTSTORE_SECRET_KEY:-}")"
export OBJECTSTORE_ENDPOINT OBJECTSTORE_BUCKET OBJECTSTORE_ACCESS_KEY OBJECTSTORE_SECRET_KEY

exec /opt/homebrew/bin/cliproxyapi "$@"
