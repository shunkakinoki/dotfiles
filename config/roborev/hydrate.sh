#!/usr/bin/env bash
# Hydrate roborev config from .env secrets
# ROBOREV_CI_REPOS: comma-separated list of repos (e.g. "org/repo1,org/repo2")
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

# Build TOML array from comma-separated list
IFS=',' read -ra REPOS <<<"$ROBOREV_CI_REPOS"
TOML_REPOS=""
for i in "${!REPOS[@]}"; do
  repo="$(echo "${REPOS[$i]}" | xargs)"
  if [ "$i" -gt 0 ]; then
    TOML_REPOS+=", "
  fi
  TOML_REPOS+="\"${repo}\""
done

mkdir -p "$CONFIG_DIR"

@sed@ \
  -e "s|\"__ROBOREV_CI_REPOS__\"|${TOML_REPOS}|g" \
  "$TEMPLATE" >"$CONFIG"
chmod 600 "$CONFIG"

echo "Generated roborev config at $CONFIG" >&2
