#!/usr/bin/env bash
# shellcheck source=/dev/null
set -euo pipefail
. "@common@"

CONFIG_DIR="${HOME}/.cli-proxy-api"
TEMPLATE="$CONFIG_DIR/config.template.yaml"
CONFIG="$CONFIG_DIR/config.yaml"
AUTH_DIR="${CONFIG_DIR}/objectstore/auths"
USAGE_EXPORT_FILE="${CONFIG_DIR}/usage-export.json"
MANAGEMENT_URL="${CLIPROXY_MANAGEMENT_URL:-http://127.0.0.1:8317/v0/management}"

cliproxy_init_objectstore_env
OBJECTSTORE_LOCAL_PATH="$CONFIG_DIR"
MANAGEMENT_PASSWORD="${CLIPROXY_MANAGEMENT_PASSWORD:-}"
MANAGEMENT_KEY="${CLIPROXY_MANAGEMENT_PASSWORD:-${CLIPROXY_MANAGEMENT_KEY:-}}"
export OBJECTSTORE_ENDPOINT OBJECTSTORE_BUCKET OBJECTSTORE_ACCESS_KEY OBJECTSTORE_SECRET_KEY OBJECTSTORE_LOCAL_PATH MANAGEMENT_PASSWORD

render_opencode_api_key_entries() {
  local template="$1"
  local key_source="${OPENCODE_API_KEYS:-${OPENCODE_API_KEY:-}}"
  local candidate existing_key trimmed escaped line
  local -a candidates=()
  local -a api_keys=()

  if [ -n "$key_source" ]; then
    IFS=',' read -r -a candidates <<<"$key_source"
  fi

  for candidate in "${candidates[@]}"; do
    trimmed="${candidate#"${candidate%%[![:space:]]*}"}"
    trimmed="${trimmed%"${trimmed##*[![:space:]]}"}"
    [ -n "$trimmed" ] || continue

    for existing_key in "${api_keys[@]}"; do
      if [ "$existing_key" = "$trimmed" ]; then
        trimmed=""
        break
      fi
    done
    [ -n "$trimmed" ] && api_keys+=("$trimmed")
  done

  while IFS= read -r line || [ -n "$line" ]; do
    if [ "$line" != "    api-key-entries: __OPENCODE_API_KEY_ENTRIES__" ]; then
      printf '%s\n' "$line"
      continue
    fi

    if [ "${#api_keys[@]}" -eq 0 ]; then
      printf '%s\n' '    api-key-entries: []'
      continue
    fi

    printf '%s\n' '    api-key-entries:'
    for candidate in "${api_keys[@]}"; do
      escaped="${candidate//\\/\\\\}"
      escaped="${escaped//\"/\\\"}"
      printf '      - api-key: "%s"\n' "$escaped"
    done
  done <"$template"
}

# Empty hydrated keys still register as clients. After a higher hop 429s,
# session-affinity binds to that empty key and never reaches OpenRouter.
cliproxy_drop_empty_compat_providers() {
  local src="$1"
  local dest="${2:-$1}"
  local tmp in_compat=0 in_item=0 has_key=0
  local item="" line keyval

  flush_item() {
    if [ "$in_item" -eq 0 ]; then
      return 0
    fi
    if [ "$has_key" -eq 1 ]; then
      printf '%s' "$item"
    else
      echo "⚠️  Dropping openai-compatibility provider with empty api-key" >&2
    fi
    item=""
    in_item=0
    has_key=0
  }

  tmp="$(mktemp "${TMPDIR:-/tmp}/cliproxy-compat.XXXXXX")"
  {
    while IFS= read -r line || [ -n "$line" ]; do
      if [ "$in_compat" -eq 0 ]; then
        printf '%s\n' "$line"
        if [ "$line" = "openai-compatibility:" ]; then
          in_compat=1
        fi
        continue
      fi

      if [[ "$line" == "#"* ]] || [[ "$line" =~ ^[A-Za-z] ]]; then
        flush_item
        in_compat=0
        printf '%s\n' "$line"
        continue
      fi

      if [[ "$line" == "  - "* ]]; then
        flush_item
        in_item=1
        item="${line}"$'\n'
        continue
      fi

      if [ "$in_item" -eq 1 ]; then
        item+="${line}"$'\n'
        if [[ "$line" == *"api-key:"* ]]; then
          keyval="${line#*api-key:}"
          keyval="${keyval#"${keyval%%[![:space:]]*}"}"
          keyval="${keyval%\"}"
          keyval="${keyval#\"}"
          keyval="${keyval%\'}"
          keyval="${keyval#\'}"
          if [ -n "$keyval" ] && [ "$keyval" != "[]" ]; then
            has_key=1
          fi
        fi
        continue
      fi

      printf '%s\n' "$line"
    done
    flush_item
  } <"$src" >"$tmp"
  mv -f "$tmp" "$dest"
} # cliproxy_drop_empty_compat_providers

if cliproxy_has_objectstore_credentials; then
  mkdir -p "$AUTH_DIR"

  if [ -z "$(ls -A "$AUTH_DIR" 2>/dev/null)" ]; then
    echo "⚠️  Local auth cache empty; hydrating from S3" >&2
    cliproxy_sync_auth_from_s3 "$AUTH_DIR"
  fi

  if [ -n "$(ls -A "$AUTH_DIR" 2>/dev/null)" ]; then
    cliproxy_sync_auth_to_s3 "$AUTH_DIR"
  fi

  if [ ! -f "$USAGE_EXPORT_FILE" ]; then
    echo "⚠️  Usage export missing locally; hydrating from S3" >&2
    cliproxy_download_usage_from_s3 "$USAGE_EXPORT_FILE"
  fi
fi

# Generate config from template
if [ -f "$TEMPLATE" ]; then
  render_opencode_api_key_entries "$TEMPLATE" | @sed@ \
    -e "s|__OPENROUTER_API_KEY__|${OPENROUTER_API_KEY:-}|g" \
    -e "s|__OPENAI_API_KEY__|${OPENAI_API_KEY:-}|g" \
    -e "s|__CLIPROXY_MANAGEMENT_PASSWORD__|${CLIPROXY_MANAGEMENT_PASSWORD:-}|g" \
    -e "s|__ZAI_API_KEY__|${ZAI_API_KEY:-}|g" \
    -e "s|__QWEN_API_KEY__|${QWEN_API_KEY:-${DASHSCOPE_API_KEY:-}}|g" \
    -e "s|__ALIYUN_TOKEN_PLAN_API_KEY__|${ALIYUN_TOKEN_PLAN_API_KEY:-}|g" \
    -e "s|__VERBOO_API_KEY__|${VERBOO_API_KEY:-}|g" \
    -e "s|__SURPLUS_API_KEY__|${SURPLUS_API_KEY:-}|g" \
    -e "s|__COMMANDCODE_API_KEY__|${COMMANDCODE_API_KEY:-}|g" \
    -e "s|__AMP_UPSTREAM_API_KEY__|${AMP_UPSTREAM_API_KEY:-}|g" \
    >"$CONFIG"

  if [ "$(uname)" = "Linux" ] && [ -n "${CLIPROXY_API_KEY:-}" ]; then
    @sed@ -i \
      -e "s|^# api-keys:|api-keys:|" \
      -e "s|^#   - \"__CLIPROXY_API_KEY__\"|  - \"${CLIPROXY_API_KEY}\"|" \
      "$CONFIG"
  fi

  # Disable AMP on Linux (causes routing issues with antigravity provider)
  if [ "$(uname)" = "Linux" ]; then
    @sed@ -i \
      -e "s|^ampcode:|# ampcode:|" \
      -e "s|^  upstream-url:|#   upstream-url:|" \
      -e "s|^  upstream-api-key:|#   upstream-api-key:|" \
      -e "s|^  restrict-management-to-localhost:|#   restrict-management-to-localhost:|" \
      -e "s|^  # Map non-prefixed|#   # Map non-prefixed|" \
      -e "s|^  model-mappings:|#   model-mappings:|" \
      -e "s|^    - from:|#     - from:|" \
      -e "s|^      to:|#       to:|" \
      "$CONFIG"
  fi

  cliproxy_drop_empty_compat_providers "$CONFIG"
fi

# Keep objectstore-backed config in sync for management UI
OBJECTSTORE_CONFIG_DIR="$CONFIG_DIR/objectstore/config"
OBJECTSTORE_CONFIG="$OBJECTSTORE_CONFIG_DIR/config.yaml"
BACKUP_CONFIG_DIR="$CONFIG_DIR/backup/config"
BACKUP_CONFIG="$BACKUP_CONFIG_DIR/config.yaml"
mkdir -p "$OBJECTSTORE_CONFIG_DIR" "$BACKUP_CONFIG_DIR"
rm -f "$OBJECTSTORE_CONFIG" "$BACKUP_CONFIG"
cp "$CONFIG" "$OBJECTSTORE_CONFIG"
cp "$CONFIG" "$BACKUP_CONFIG"

# Push config to objectstore so remote-backed config doesn't revert locally
if [ -n "$OBJECTSTORE_ENDPOINT" ] && [ -n "$OBJECTSTORE_ACCESS_KEY" ] && [ -n "$OBJECTSTORE_SECRET_KEY" ]; then
  AWS_ACCESS_KEY_ID="$OBJECTSTORE_ACCESS_KEY" \
    AWS_SECRET_ACCESS_KEY="$OBJECTSTORE_SECRET_KEY" \
    @aws@ s3 sync \
    --endpoint-url="$OBJECTSTORE_ENDPOINT" \
    --no-progress \
    "$OBJECTSTORE_CONFIG_DIR/" \
    "s3://${OBJECTSTORE_BUCKET}/config/" || true

  AWS_ACCESS_KEY_ID="$OBJECTSTORE_ACCESS_KEY" \
    AWS_SECRET_ACCESS_KEY="$OBJECTSTORE_SECRET_KEY" \
    @aws@ s3 sync \
    --endpoint-url="$OBJECTSTORE_ENDPOINT" \
    --no-progress \
    "$BACKUP_CONFIG_DIR/" \
    "s3://${OBJECTSTORE_BUCKET}/backup/config/" || true
fi

cd "$CONFIG_DIR"

# Linux: Docker
usage_import() {
  if [ -z "$MANAGEMENT_KEY" ] || [ ! -f "$USAGE_EXPORT_FILE" ]; then
    return 0
  fi
  curl -sS --max-time 10 \
    -H "Authorization: Bearer ${MANAGEMENT_KEY}" \
    -H "Content-Type: application/json" \
    -X POST \
    --data-binary @"$USAGE_EXPORT_FILE" \
    "${MANAGEMENT_URL}/usage/import" >/dev/null || true
}

# shellcheck disable=SC2329 # Invoked via trap
usage_export() {
  if [ -z "${MANAGEMENT_KEY:-}" ] || [ -z "${USAGE_EXPORT_FILE:-}" ]; then
    return 0
  fi
  mkdir -p "$(dirname "$USAGE_EXPORT_FILE")"
  curl -sS --max-time 5 \
    -H "Authorization: Bearer ${MANAGEMENT_KEY}" \
    "${MANAGEMENT_URL}/usage/export" \
    -o "$USAGE_EXPORT_FILE" || true
  cliproxy_upload_usage_to_s3 "$USAGE_EXPORT_FILE"
}

apply_systemd_cgroup_weights() {
  local container_id=""
  local unit=""
  local attempts=50
  local -a root_cmd=()

  command -v systemctl >/dev/null 2>&1 || return 0
  if [ "$(id -u)" -ne 0 ]; then
    if command -v sudo >/dev/null 2>&1; then
      root_cmd=(sudo -n)
    else
      echo "⚠️  Cannot apply CLIProxy cgroup-v2 weights without non-interactive root access" >&2
      return 0
    fi
  fi

  while [ "$attempts" -gt 0 ]; do
    container_id="$(docker inspect --format '{{.Id}}' cliproxyapi 2>/dev/null || true)"
    if [ -n "$container_id" ]; then
      unit="docker-${container_id}.scope"
      if "${root_cmd[@]}" systemctl set-property --runtime "$unit" \
        CPUWeight=10000 IOWeight=10000 2>/dev/null; then
        echo "Applied CLIProxy cgroup-v2 CPU and I/O weights to $unit"
        return 0
      fi
    fi
    attempts=$((attempts - 1))
    sleep 0.1
  done

  echo "⚠️  Could not apply CLIProxy cgroup-v2 weights; Docker limits remain in effect" >&2
}

wait_for_management() {
  if [ -z "$MANAGEMENT_KEY" ]; then
    return 0
  fi
  local attempts=60
  for _ in $(seq 1 "$attempts"); do
    if curl -sS --max-time 3 \
      -H "Authorization: Bearer ${MANAGEMENT_KEY}" \
      "${MANAGEMENT_URL}/usage/export" \
      -o /dev/null; then
      return 0
    fi
    sleep 3
  done
  return 1
}

# Remove any stale cliproxyapi container and verify dockerd has released the name.
# Previous SIGKILL of the service can leave the container running inside dockerd
# even though the docker client went away, causing "name already in use" on restart.
ensure_container_removed() {
  local name="$1"
  docker rm -f "$name" 2>/dev/null || true
  for _ in 1 2 3 4 5; do
    if ! docker inspect "$name" >/dev/null 2>&1; then
      return 0
    fi
    sleep 1
    docker rm -f "$name" 2>/dev/null || true
  done
  docker inspect "$name" >/dev/null 2>&1 && return 1
  return 0
}

child_pid=""
helper_pid=""
trap 'usage_export' EXIT
# On shutdown, stop the container via dockerd (not kill on the client PID), so
# --rm cleanup runs and the name is freed before the next start.
trap '
  usage_export
  if [ -n "$helper_pid" ]; then
    kill -TERM "$helper_pid" 2>/dev/null || true
  fi
  docker stop --time 15 cliproxyapi 2>/dev/null || docker rm -f cliproxyapi 2>/dev/null || true
  if [ -n "$child_pid" ]; then
    wait "$child_pid" 2>/dev/null || true
  fi
' TERM INT

if [ "$(uname)" = "Linux" ] && command -v docker >/dev/null 2>&1; then
  docker_image="${CLIPROXYAPI_IMAGE:-eceasy/cli-proxy-api:latest}"
  if docker info >/dev/null 2>&1; then
    if [ "${CLIPROXYAPI_SKIP_PULL:-false}" != "true" ]; then
      echo "🔄 Pulling cliproxyapi image ${docker_image}..."
      docker pull "$docker_image" || true
    fi
  else
    echo "⏭️ Skipping docker pull (docker not accessible)"
  fi

  if ! ensure_container_removed cliproxyapi; then
    echo "⚠️  Failed to remove stale cliproxyapi container; aborting" >&2
    exit 1
  fi
  mkdir -p "$CONFIG_DIR/logs"

  # Probe management endpoint and import usage in a background helper so the
  # main shell can wait on docker run without the poll loop blocking signals.
  (
    wait_for_management || exit 0
    usage_import
  ) &
  helper_pid=$!

  docker run --rm \
    --name cliproxyapi \
    --network host \
    --cpu-shares 262144 \
    --blkio-weight 1000 \
    --ulimit nofile=65536:65536 \
    -v "$CONFIG:/CLIProxyAPI/config.yaml:ro" \
    -v "$CONFIG_DIR:/root/.cli-proxy-api" \
    -v "$CONFIG_DIR/logs:/CLIProxyAPI/logs" \
    -e MANAGEMENT_PASSWORD="${MANAGEMENT_PASSWORD:-}" \
    "$docker_image" &
  child_pid=$!
  apply_systemd_cgroup_weights
  wait "$child_pid"
  exit $?
fi

# macOS: Homebrew binary
if [ -x /opt/homebrew/bin/cliproxyapi ]; then
  /opt/homebrew/bin/cliproxyapi -config "$CONFIG" "$@" &
  child_pid=$!
  wait_for_management || true
  usage_import
  wait "$child_pid"
  exit $?
elif [ -x /usr/local/bin/cliproxyapi ]; then
  /usr/local/bin/cliproxyapi -config "$CONFIG" "$@" &
  child_pid=$!
  wait_for_management || true
  usage_import
  wait "$child_pid"
  exit $?
else
  echo "cliproxyapi not found" >&2
  exit 1
fi
