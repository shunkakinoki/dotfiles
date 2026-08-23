#!/usr/bin/env bash
# Push CLIProxyAPI state to S3.
#
# "auth" syncs only the kilobyte-scale auth cache and is the mode wired to the
# auth-directory watch, which fires on every CLIProxyAPI token refresh. "full"
# adds the gigabyte-scale CPA Manager Plus analytics snapshot and must stay on a
# wall-clock schedule; running it per token refresh saturated kyber's disk.
# shellcheck source=/dev/null
set -euo pipefail
. "@common@"

MODE="${1:-auth}"
case "$MODE" in
auth | full) ;;
*)
  echo "usage: backup.sh [auth|full]" >&2
  exit 2
  ;;
esac

AUTH_DIR="${HOME}/.cli-proxy-api/objectstore/auths"
cliproxy_init_objectstore_env
CPA_MANAGER_PLUS_DATA_DIR="${CPA_MANAGER_PLUS_DATA_DIR:-${HOME}/.cpa-manager-plus}"

if ! cliproxy_has_objectstore_credentials; then
  echo "⚠️  Missing S3 credentials, skipping backup" >&2
  exit 0
fi

if [ -d "$AUTH_DIR" ] && [ -n "$(ls -A "$AUTH_DIR" 2>/dev/null)" ]; then
  echo "[$(date)] Backing up auth files..." >&2

  cliproxy_sync_auth_to_s3 "$AUTH_DIR"
else
  echo "⚠️  No auth files to backup" >&2
fi

if [ "$MODE" != "full" ]; then
  exit 0
fi

if [ -d "$CPA_MANAGER_PLUS_DATA_DIR" ]; then
  echo "[$(date)] Backing up CPA Manager Plus analytics..." >&2
  cliproxy_backup_manager_data "$CPA_MANAGER_PLUS_DATA_DIR"
fi
