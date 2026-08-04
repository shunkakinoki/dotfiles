#!/usr/bin/env bash
set -euo pipefail

CONTAINER_NAME="cpa-manager-plus"
ENV_FILE="${HOME}/dotfiles/.env"

if [ -f "$ENV_FILE" ]; then
  set -a
  # shellcheck source=/dev/null
  . "$ENV_FILE"
  set +a
fi

IMAGE="${CPA_MANAGER_PLUS_IMAGE:-seakee/cpa-manager-plus:latest}"
DATA_DIR="${CPA_MANAGER_PLUS_DATA_DIR:-${HOME}/.cpa-manager-plus}"

umask 077
mkdir -p "$DATA_DIR"
chmod 700 "$DATA_DIR"

ensure_container_removed() {
  @docker@ rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true
  for _ in 1 2 3 4 5; do
    if ! @docker@ inspect "$CONTAINER_NAME" >/dev/null 2>&1; then
      return 0
    fi
    sleep 1
    @docker@ rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true
  done
  ! @docker@ inspect "$CONTAINER_NAME" >/dev/null 2>&1
}

child_pid=""
trap '
  @docker@ stop --time 15 "$CONTAINER_NAME" >/dev/null 2>&1 || @docker@ rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true
  if [ -n "$child_pid" ]; then
    wait "$child_pid" 2>/dev/null || true
  fi
' TERM INT

if @docker@ info >/dev/null 2>&1; then
  echo "Pulling CPA Manager Plus image..."
  @docker@ pull "$IMAGE" || true
else
  echo "Docker is not accessible" >&2
  exit 1
fi

if ! ensure_container_removed; then
  echo "Failed to remove stale CPA Manager Plus container" >&2
  exit 1
fi

host_uid="$(id -u)"
host_gid="$(id -g)"

# Older launches ran as root inside the container. Migrate the bind-mounted data
# before switching to the service user's numeric identity.
@docker@ run --rm \
  --user 0:0 \
  -v "$DATA_DIR:/data" \
  --entrypoint chown \
  "$IMAGE" \
  -R "${host_uid}:${host_gid}" /data

docker_args=(
  run
  --rm
  --name "$CONTAINER_NAME"
  --user "${host_uid}:${host_gid}"
  --network host
  --ulimit nofile=65536:65536
  -v "$DATA_DIR:/data"
  # Kubernetes reaches this host port through a selectorless Service. CPA
  # Manager Plus protects the UI with the configured or first-run admin key.
  -e "HTTP_ADDR=0.0.0.0:18317"
  -e "USAGE_DB_PATH=/data/usage.sqlite"
  -e "CPA_MANAGER_DATA_KEY_PATH=/data/data.key"
  -e "USAGE_COLLECTOR_MODE=auto"
  -e "USAGE_BATCH_SIZE=100"
  -e "USAGE_POLL_INTERVAL_MS=500"
  -e "USAGE_QUERY_LIMIT=50000"
)

if [ -n "${CPA_MANAGER_ADMIN_KEY:-}" ]; then
  export CPA_MANAGER_ADMIN_KEY
  docker_args+=(-e CPA_MANAGER_ADMIN_KEY)
fi

management_key="${CLIPROXY_MANAGEMENT_PASSWORD:-${CLIPROXY_MANAGEMENT_KEY:-}}"
if [ -n "$management_key" ]; then
  export CPA_MANAGEMENT_KEY="$management_key"
  docker_args+=(
    -e "CPA_UPSTREAM_URL=http://127.0.0.1:8317"
    -e CPA_MANAGEMENT_KEY
  )
fi

@docker@ "${docker_args[@]}" "$IMAGE" &
child_pid=$!
wait "$child_pid"
