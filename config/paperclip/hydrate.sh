#!/usr/bin/env bash
set -euo pipefail

INSTANCE_DIR="@instance_dir@"
CONFIG="${INSTANCE_DIR}/config.json"
TEMPLATE="@template@"
ENV_FILE="${HOME}/dotfiles/.env"

# Source .env if it exists (for DATABASE_URL)
if [ -f "$ENV_FILE" ]; then
  set -a
  # shellcheck source=/dev/null
  . "$ENV_FILE"
  set +a
fi

mkdir -p "${INSTANCE_DIR}"

# Use DATABASE_URL from env if set, otherwise use the Nix default
DB_CONNECTION="${DATABASE_URL:-@database_connection_string@}"

@sed@ \
  -e "s|__DATABASE_MODE__|@database_mode@|g" \
  -e "s|__DATABASE_CONNECTION_STRING__|${DB_CONNECTION}|g" \
  -e "s|__DEPLOYMENT_MODE__|@deployment_mode@|g" \
  -e "s|__HOST__|@host@|g" \
  -e "s|__ALLOWED_HOSTNAME__|@allowed_hostname@|g" \
  "$TEMPLATE" >"$CONFIG"
chmod 600 "$CONFIG"

# Create paperclip database on k8s postgres if needed
# @is_kyber@ is substituted by Nix replaceVars
# shellcheck disable=SC2050
if [ "@is_kyber@" = "true" ] && [ -n "$DB_CONNECTION" ]; then
  if command -v psql >/dev/null 2>&1; then
    DB_BASE="${DB_CONNECTION%/*}/postgres"
    if ! psql "$DB_BASE" -tAc "SELECT 1 FROM pg_database WHERE datname='paperclip'" 2>/dev/null | grep -q 1; then
      psql "$DB_BASE" -c "CREATE DATABASE paperclip" 2>/dev/null && echo "Created paperclip database" >&2
    fi
  fi
fi
