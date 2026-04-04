#!/usr/bin/env bash
set -euo pipefail

INSTANCE_DIR="@instance_dir@"
CONFIG="${INSTANCE_DIR}/config.json"
TEMPLATE="@template@"

mkdir -p "${INSTANCE_DIR}"

@sed@ \
  -e "s|__DATABASE_MODE__|@database_mode@|g" \
  -e "s|__DATABASE_CONNECTION_STRING__|@database_connection_string@|g" \
  -e "s|__DEPLOYMENT_MODE__|@deployment_mode@|g" \
  -e "s|__HOST__|@host@|g" \
  -e "s|__ALLOWED_HOSTNAME__|@allowed_hostname@|g" \
  "$TEMPLATE" >"$CONFIG"
chmod 600 "$CONFIG"

# Create paperclip database on docker-postgres if needed
# @is_kyber@ is substituted by Nix replaceVars
# shellcheck disable=SC2050
if [ "@is_kyber@" = "true" ]; then
  if command -v docker >/dev/null 2>&1 && docker container inspect postgres >/dev/null 2>&1; then
    if ! docker exec postgres psql -U postgres -lqt | cut -d \| -f 1 | grep -qw paperclip; then
      docker exec postgres createdb -U postgres paperclip
      echo "Created paperclip database" >&2
    fi
  fi
fi
