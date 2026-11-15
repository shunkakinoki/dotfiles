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
  # OAuth auth files rotate their refresh tokens on every refresh, so they live
  # on one host only. Other hosts run CLIProxyAPI without the shared S3 store.
  local objectstore_enabled="@objectstore_enabled@"
  if [ "$objectstore_enabled" != "true" ]; then
    OBJECTSTORE_ENDPOINT=""
    OBJECTSTORE_ACCESS_KEY=""
    OBJECTSTORE_SECRET_KEY=""
  fi
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

cliproxy_read_auth_from_s3() {
  local name="$1"
  AWS_ACCESS_KEY_ID="$OBJECTSTORE_ACCESS_KEY" \
    AWS_SECRET_ACCESS_KEY="$OBJECTSTORE_SECRET_KEY" \
    @aws@ s3 cp \
    --endpoint-url="$OBJECTSTORE_ENDPOINT" \
    --only-show-errors \
    "$(cliproxy_auth_s3_uri)${name}" \
    -
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
  local object_name="${1:-analytics-backup.tar.gz}"
  printf 's3://%s/cpa-manager-plus/%s' "${OBJECTSTORE_BUCKET:?OBJECTSTORE_BUCKET is required}" "$object_name"
}

cliproxy_promote_manager_backup() {
  local source_object="$1"
  local destination_object="${2:-analytics-backup.tar.gz}"
  AWS_ACCESS_KEY_ID="$OBJECTSTORE_ACCESS_KEY" \
    AWS_SECRET_ACCESS_KEY="$OBJECTSTORE_SECRET_KEY" \
    @aws@ s3api copy-object \
    --endpoint-url="$OBJECTSTORE_ENDPOINT" \
    --bucket="$OBJECTSTORE_BUCKET" \
    --key="cpa-manager-plus/${destination_object}" \
    --copy-source="${OBJECTSTORE_BUCKET}/cpa-manager-plus/${source_object}" \
    --no-cli-pager \
    >/dev/null
}

cliproxy_backup_manager_data() (
  set -euo pipefail
  umask 077

  local data_dir="$1"
  local database_path="${data_dir}/usage.sqlite"
  local data_key_path="${data_dir}/data.key"
  local staging_root backup_root archive_path checkpoint hourly_object
  local copy_timeout="${CLIPROXY_BACKUP_COPY_TIMEOUT:-30m}"
  local manager_unit="cpa-manager-plus.service"
  local manager_stopped=0

  if [ ! -f "$database_path" ] || [ ! -f "$data_key_path" ]; then
    echo "⚠️  CPA Manager Plus database or data key is missing; skipping analytics backup" >&2
    return 0
  fi

  staging_root="${CLIPROXY_BACKUP_STAGING_DIR:-${TMPDIR:-/tmp}}"
  mkdir -p "$staging_root"
  backup_root="$(mktemp -d "${staging_root%/}/cpa-manager-plus-backup.XXXXXX")"
  archive_path="${backup_root}/analytics-backup.tar.gz"

  restore_manager() {
    if [ "$manager_stopped" -eq 1 ]; then
      manager_stopped=0
      systemctl --user start "$manager_unit" || true
    fi
  }
  trap 'restore_manager; rm -rf -- "$backup_root"' EXIT

  # Snapshotting with a read transaction that stays open for the whole copy
  # (VACUUM INTO, .backup) pins the WAL: SQLite cannot reset it while a reader
  # holds a snapshot, and the manager writes every 500 ms. On 2026-10-19 that
  # left an 84 GB -wal against a 28 GB database and put kyber's root disk at
  # 76%. Pause the manager instead: with no writer the WAL folds back into the
  # database, and archiving a fully checkpointed database file is consistent.
  if systemctl --user is-active --quiet "$manager_unit"; then
    manager_stopped=1
    systemctl --user stop "$manager_unit"
  fi

  # Result is busy|wal_frames|checkpointed_frames; a busy checkpoint leaves
  # committed pages in the WAL, which the archive would not contain.
  checkpoint="$(@sqlite3@ "$database_path" ".timeout 30000" "PRAGMA wal_checkpoint(TRUNCATE);")"
  if [ "${checkpoint%%|*}" != "0" ]; then
    echo "CPA Manager Plus WAL checkpoint did not complete (${checkpoint})" >&2
    return 1
  fi

  # Compress while archiving instead of staging a raw copy: kyber's root disk
  # is a nearly full QLC SSD, and writing a second 60+ GB file there is what
  # kept blowing the pause budget. Reading the database is the only full-size
  # I/O; the archive is about a fifth of it. The manager also serves the
  # public management UI, so the pause stays bounded no matter how slow the
  # disk is.
  if ! timeout "$copy_timeout" @tar@ -cf - -C "$data_dir" usage.sqlite data.key |
    @pigz@ -1 >"$archive_path"; then
    echo "CPA Manager Plus database archive failed or exceeded ${copy_timeout}" >&2
    return 1
  fi
  restore_manager

  if ! @pigz@ -t "$archive_path"; then
    echo "CPA Manager Plus analytics archive failed its integrity check" >&2
    return 1
  fi

  # Keep one rollback point per UTC hour in addition to the convenient latest
  # object.
  hourly_object="analytics-backup-$(date -u +%H).tar.gz"
  AWS_ACCESS_KEY_ID="$OBJECTSTORE_ACCESS_KEY" \
    AWS_SECRET_ACCESS_KEY="$OBJECTSTORE_SECRET_KEY" \
    @aws@ s3 cp \
    --endpoint-url="$OBJECTSTORE_ENDPOINT" \
    --only-show-errors \
    "$archive_path" \
    "$(cliproxy_manager_backup_s3_uri "$hourly_object")"

  # Server-side copy: use the low-level API because this S3-compatible backend
  # does not implement GetObjectTagging, which the high-level `s3 cp` command
  # requests while preserving tags.
  cliproxy_promote_manager_backup "$hourly_object"
)
