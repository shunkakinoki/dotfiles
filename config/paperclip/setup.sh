#!/usr/bin/env bash
set -euo pipefail

INSTANCE_DIR="@instance_dir@"
CONFIG="${INSTANCE_DIR}/config.json"

mkdir -p "${INSTANCE_DIR}"

@cp@ "@config_file@" "$CONFIG"
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
