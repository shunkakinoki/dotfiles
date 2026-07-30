#!/usr/bin/env bash
# Hydrate roborev config from .env secrets
# shellcheck source=/dev/null
set -euo pipefail

CONFIG_DIR="${HOME}/.roborev"
CONFIG="${CONFIG_DIR}/config.toml"
TEMPLATE="@template@"
ENV_FILE="${HOME}/dotfiles/.env"

if [ -f "$ENV_FILE" ]; then
  set -a
  . "$ENV_FILE"
  set +a
fi

ROBOREV_CI_REPOS="${ROBOREV_CI_REPOS:-}"

if [ -z "$ROBOREV_CI_REPOS" ]; then
  echo "Warning: ROBOREV_CI_REPOS not set, skipping roborev hydration" >&2
  exit 0
fi

mkdir -p "$CONFIG_DIR"

@sed@ \
  -e "s|__ROBOREV_CI_REPOS__|${ROBOREV_CI_REPOS}|g" \
  "$TEMPLATE" >"$CONFIG"
chmod 600 "$CONFIG"

echo "Generated roborev config at $CONFIG" >&2
