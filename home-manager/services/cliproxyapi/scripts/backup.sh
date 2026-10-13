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

  # The container runs as root and writes new auth files as root:0600, which
  # this user cannot read, so `s3 sync` would skip them forever. Only files
  # with the wrong owner are touched because every chown fires the watcher.
  if command -v docker >/dev/null 2>&1; then
    docker exec cliproxyapi find /root/.cli-proxy-api/objectstore/auths \
      -maxdepth 1 -type f ! -uid "$(id -u)" \
      -exec chown "$(id -u):$(id -g)" {} + 2>/dev/null || true
  fi

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
