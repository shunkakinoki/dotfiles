#!/usr/bin/env bash
set -euo pipefail

ENV_FILE="${HOME}/dotfiles/.env"
if [ -f "$ENV_FILE" ]; then
  set -a
  . "$ENV_FILE"
  set +a
fi

strip_quotes() { local v="$1"; v="${v%\"}"; v="${v#\"}"; printf '%s' "$v"; }
export OBJECTSTORE_ENDPOINT="$(strip_quotes "${OBJECTSTORE_ENDPOINT:-}")"
export OBJECTSTORE_BUCKET="$(strip_quotes "${OBJECTSTORE_BUCKET:-cliproxyapi}")"
export OBJECTSTORE_ACCESS_KEY="$(strip_quotes "${OBJECTSTORE_ACCESS_KEY:-}")"
export OBJECTSTORE_SECRET_KEY="$(strip_quotes "${OBJECTSTORE_SECRET_KEY:-}")"

exec /opt/homebrew/bin/cliproxyapi "$@"
