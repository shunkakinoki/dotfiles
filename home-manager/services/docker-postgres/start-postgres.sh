#!/usr/bin/env bash
set -euo pipefail

CONTAINER_NAME="postgres"
IMAGE="postgres:18"
HOST_PORT="5432"
CONTAINER_PORT="5432"
MAX_RETRIES=30
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
    local state
    state=$(docker container inspect --format '{{.State.Status}}' "$CONTAINER_NAME")
    if [ "$state" = "running" ]; then
      log "Container '$CONTAINER_NAME' is already running"
      return 0
    fi
    log "Container '$CONTAINER_NAME' exists but is $state, starting..."
    docker start "$CONTAINER_NAME"
    log "Container '$CONTAINER_NAME' started"
  else
    log "Container '$CONTAINER_NAME' does not exist, creating..."
    docker run -d \
      --name "$CONTAINER_NAME" \
      --restart=unless-stopped \
      -p "${HOST_PORT}:${CONTAINER_PORT}" \
      -e POSTGRES_DB=trails_api \
      -e POSTGRES_PASSWORD=postgres \
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
      log "PostgreSQL is ready and accepting connections"
      return 0
    fi
    attempt=$((attempt + 1))
    sleep 2
  done
  log "WARNING: PostgreSQL container is running but not yet accepting connections"
  return 0
}

wait_for_docker
ensure_container
verify_postgres
log "Done"
