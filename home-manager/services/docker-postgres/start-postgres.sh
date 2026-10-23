#!/usr/bin/env bash
set -euo pipefail

CONTAINER_NAME="postgres"
IMAGE="postgres:18"
HOST_PORT="5432"
CONTAINER_PORT="5432"
DATA_VOLUME="${POSTGRES_DATA_VOLUME:-postgres-data}"
PASSWORD_FILE="${POSTGRES_PASSWORD_FILE:-${XDG_STATE_HOME:-$HOME/.local/state}/docker-postgres/password}"
MAX_RETRIES=60
RETRY_INTERVAL=5

log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') [docker-postgres] $*"
}

wait_for_docker() {
  log "Waiting for Docker daemon..."
  local attempt=0
  while [ "$attempt" -lt "$MAX_RETRIES" ]; do
    if docker info >/dev/null 2>&1; then
      log "Docker daemon is ready"
      return 0
    fi
    attempt=$((attempt + 1))
    log "Docker not ready (attempt $attempt/$MAX_RETRIES), retrying in ${RETRY_INTERVAL}s..."
    sleep "$RETRY_INTERVAL"
  done
  log "ERROR: Docker daemon did not become available after $((MAX_RETRIES * RETRY_INTERVAL))s"
  return 1
}

ensure_container() {
  if docker container inspect "$CONTAINER_NAME" >/dev/null 2>&1; then
    local state binding trust
    binding=$(docker container inspect --format '{{range (index .HostConfig.PortBindings "5432/tcp")}}{{.HostIp}}:{{.HostPort}}{{"\n"}}{{end}}' "$CONTAINER_NAME")
    trust=$(docker container inspect --format '{{range .Config.Env}}{{if eq . "POSTGRES_HOST_AUTH_METHOD=trust"}}trust{{end}}{{end}}' "$CONTAINER_NAME")
    if [ "$binding" != "127.0.0.1:${HOST_PORT}" ] || [ "$trust" = trust ]; then
      log "ERROR: Existing container requires a storage-preserving security migration; see docker-postgres/README.md"
      return 1
    fi
    state=$(docker container inspect --format '{{.State.Status}}' "$CONTAINER_NAME")
    if [ "$state" = "running" ]; then
      log "Container '$CONTAINER_NAME' is already running"
      return 0
    fi
    log "Container '$CONTAINER_NAME' exists but is $state, starting..."
    docker start "$CONTAINER_NAME"
    log "Container '$CONTAINER_NAME' started"
  else
    umask 077
    mkdir -p "$(dirname "$PASSWORD_FILE")"
    if [ ! -s "$PASSWORD_FILE" ]; then
      od -An -N32 -tx1 /dev/urandom | tr -d ' \n' >"$PASSWORD_FILE"
    fi
    chmod 600 "$PASSWORD_FILE"
    log "Container '$CONTAINER_NAME' does not exist, creating..."
    docker run -d \
      --name "$CONTAINER_NAME" \
      --restart=unless-stopped \
      -p "127.0.0.1:${HOST_PORT}:${CONTAINER_PORT}" \
      --mount "type=volume,src=${DATA_VOLUME},dst=/var/lib/postgresql" \
      --mount "type=bind,src=${PASSWORD_FILE},dst=/run/secrets/postgres-password,readonly" \
      -e POSTGRES_DB=trails_api \
      -e POSTGRES_PASSWORD_FILE=/run/secrets/postgres-password \
      -e POSTGRES_HOST_AUTH_METHOD=scram-sha-256 \
      "$IMAGE"
    log "Container '$CONTAINER_NAME' created and started"
  fi
}

verify_postgres() {
  log "Verifying PostgreSQL is accepting connections..."
  local attempt=0
  local max_verify=12
  while [ "$attempt" -lt "$max_verify" ]; do
    if docker exec "$CONTAINER_NAME" pg_isready -U postgres >/dev/null 2>&1; then
      local trust_rules
      trust_rules=$(docker exec "$CONTAINER_NAME" psql -U postgres -d postgres -At -v ON_ERROR_STOP=1 \
        -c "SELECT count(*) FROM pg_hba_file_rules WHERE error IS NOT NULL OR (type IN ('host', 'hostssl', 'hostnossl') AND auth_method = 'trust');")
      if [ "$trust_rules" != 0 ]; then
        log "ERROR: PostgreSQL has unsafe or invalid network authentication rules; see docker-postgres/README.md"
        return 1
      fi
      log "PostgreSQL is ready and accepting connections"
      return 0
    fi
    attempt=$((attempt + 1))
    sleep 2
  done
  log "ERROR: PostgreSQL did not become ready"
  return 1
}

wait_for_docker
ensure_container
verify_postgres
log "Done"
