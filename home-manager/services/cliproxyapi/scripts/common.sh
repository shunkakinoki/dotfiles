#!/usr/bin/env bash

cliproxy_load_env() {
  local env_file="${HOME}/dotfiles/.env"
  if [ -f "$env_file" ]; then
    set -a
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
