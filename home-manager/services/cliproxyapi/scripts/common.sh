#!/usr/bin/env bash

cliproxy_load_env() {
  local env_file="${HOME}/dotfiles/.env"
  if [ -f "$env_file" ]; then
    set -a
    # shellcheck source=/dev/null
    . "$env_file"
    set +a
  fi
}

cliproxy_strip_quotes() {
  local value="$1"
  value="${value%\"}"
  value="${value#\"}"
  printf '%s' "$value"
}

cliproxy_init_objectstore_env() {
  cliproxy_load_env
  OBJECTSTORE_ENDPOINT="$(cliproxy_strip_quotes "${OBJECTSTORE_ENDPOINT:-}")"
  OBJECTSTORE_BUCKET="$(cliproxy_strip_quotes "${OBJECTSTORE_BUCKET:-cliproxyapi}")"
  OBJECTSTORE_ACCESS_KEY="$(cliproxy_strip_quotes "${OBJECTSTORE_ACCESS_KEY:-}")"
  OBJECTSTORE_SECRET_KEY="$(cliproxy_strip_quotes "${OBJECTSTORE_SECRET_KEY:-}")"
  export OBJECTSTORE_ENDPOINT OBJECTSTORE_BUCKET OBJECTSTORE_ACCESS_KEY OBJECTSTORE_SECRET_KEY
}

cliproxy_has_objectstore_credentials() {
  [ -n "${OBJECTSTORE_ENDPOINT:-}" ] &&
    [ -n "${OBJECTSTORE_ACCESS_KEY:-}" ] &&
    [ -n "${OBJECTSTORE_SECRET_KEY:-}" ]
}

cliproxy_auth_s3_uri() {
  printf 's3://%s/auths/' "${OBJECTSTORE_BUCKET:?OBJECTSTORE_BUCKET is required}"
}

cliproxy_s3_sync() {
  local source_path="$1"
  local destination_path="$2"
  AWS_ACCESS_KEY_ID="${OBJECTSTORE_ACCESS_KEY:?OBJECTSTORE_ACCESS_KEY is required}" \
    AWS_SECRET_ACCESS_KEY="${OBJECTSTORE_SECRET_KEY:?OBJECTSTORE_SECRET_KEY is required}" \
    @aws@ s3 sync \
    --endpoint-url="${OBJECTSTORE_ENDPOINT:?OBJECTSTORE_ENDPOINT is required}" \
    --no-progress \
    "$source_path" \
    "$destination_path" || true
}

cliproxy_sync_auth_from_s3() {
  local auth_dir="$1"
  mkdir -p "$auth_dir"
  cliproxy_s3_sync "$(cliproxy_auth_s3_uri)" "$auth_dir/"
}

cliproxy_sync_auth_to_s3() {
  local auth_dir="$1"
  cliproxy_s3_sync "$auth_dir/" "$(cliproxy_auth_s3_uri)"
}

cliproxy_usage_s3_uri() {
  printf 's3://%s/usage-export.json' "${OBJECTSTORE_BUCKET:?OBJECTSTORE_BUCKET is required}"
}

cliproxy_upload_usage_to_s3() {
  local src="$1"
  [ -f "$src" ] || return 0
  cliproxy_has_objectstore_credentials || return 0
  AWS_ACCESS_KEY_ID="$OBJECTSTORE_ACCESS_KEY" \
    AWS_SECRET_ACCESS_KEY="$OBJECTSTORE_SECRET_KEY" \
    @aws@ s3 cp \
    --endpoint-url="$OBJECTSTORE_ENDPOINT" \
    --no-progress \
    "$src" \
    "$(cliproxy_usage_s3_uri)" || true
}

cliproxy_download_usage_from_s3() {
  local dst="$1"
  cliproxy_has_objectstore_credentials || return 0
  mkdir -p "$(dirname "$dst")"
  AWS_ACCESS_KEY_ID="$OBJECTSTORE_ACCESS_KEY" \
    AWS_SECRET_ACCESS_KEY="$OBJECTSTORE_SECRET_KEY" \
    @aws@ s3 cp \
    --endpoint-url="$OBJECTSTORE_ENDPOINT" \
    --no-progress \
    "$(cliproxy_usage_s3_uri)" \
    "$dst" || true
}

cliproxy_manager_backup_s3_uri() {
  printf 's3://%s/cpa-manager-plus/analytics-backup.tar.gz' "${OBJECTSTORE_BUCKET:?OBJECTSTORE_BUCKET is required}"
}

cliproxy_backup_manager_data() (
  set -euo pipefail
  umask 077

  local data_dir="$1"
  local database_path="${data_dir}/usage.sqlite"
  local data_key_path="${data_dir}/data.key"
  local backup_root snapshot_dir snapshot_path archive_path integrity

  if [ ! -f "$database_path" ] || [ ! -f "$data_key_path" ]; then
    echo "⚠️  CPA Manager Plus database or data key is missing; skipping analytics backup" >&2
    return 0
  fi

  backup_root="$(mktemp -d "${TMPDIR:-/tmp}/cpa-manager-plus-backup.XXXXXX")"
  trap 'rm -rf -- "$backup_root"' EXIT
  snapshot_dir="${backup_root}/cpa-manager-plus"
  snapshot_path="${snapshot_dir}/usage.sqlite"
  archive_path="${backup_root}/analytics-backup.tar.gz"
  mkdir -p "$snapshot_dir"

  # The live database uses WAL mode. SQLite's online backup command produces a
  # consistent standalone database without copying transient -wal/-shm files.
  sqlite3 "$database_path" ".timeout 5000" ".backup '${snapshot_path}'"

  integrity="$(sqlite3 "$snapshot_path" "PRAGMA integrity_check;")"
  if [ "$integrity" != "ok" ]; then
    echo "CPA Manager Plus SQLite snapshot failed its integrity check" >&2
    return 1
  fi

  install -m 600 "$data_key_path" "${snapshot_dir}/data.key"
  tar -czf "$archive_path" -C "$snapshot_dir" usage.sqlite data.key
  chmod 600 "$archive_path"

  AWS_ACCESS_KEY_ID="$OBJECTSTORE_ACCESS_KEY" \
    AWS_SECRET_ACCESS_KEY="$OBJECTSTORE_SECRET_KEY" \
    @aws@ s3 cp \
    --endpoint-url="$OBJECTSTORE_ENDPOINT" \
    --only-show-errors \
    "$archive_path" \
    "$(cliproxy_manager_backup_s3_uri)"
)
