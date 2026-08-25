#!/usr/bin/env bash
set -euo pipefail

readonly VERSION="@version@"
readonly SOURCE_REVISION="@source_revision@"
readonly IMAGE="crabbox-coordinator:${VERSION}"
readonly SOURCE_CONTEXT="https://github.com/openclaw/crabbox.git#${SOURCE_REVISION}:worker"
readonly POSTGRES_IMAGE="postgres:17-bookworm"
readonly NETWORK_NAME="crabbox"
readonly POSTGRES_CONTAINER="crabbox-postgres"
readonly COORDINATOR_CONTAINER="crabbox-coordinator"
readonly CONFIG_DIR="${HOME}/.config/crabbox/coordinator"
readonly GENERATED_ENV="${CONFIG_DIR}/generated.env"
readonly LOCAL_ENV="${HOME}/dotfiles/.env"

umask 077
mkdir -p "$CONFIG_DIR"

if [ ! -f "$GENERATED_ENV" ]; then
  postgres_password="$(@openssl@ rand -hex 32)"
  shared_token="cbx_$(@openssl@ rand -hex 32)"
  admin_token="cbxa_$(@openssl@ rand -hex 32)"
  session_secret="$(@openssl@ rand -hex 32)"
  {
    printf 'POSTGRES_PASSWORD=%s\n' "$postgres_password"
    printf 'DATABASE_URL=postgresql://crabbox:%s@%s:5432/crabbox\n' \
      "$postgres_password" "$POSTGRES_CONTAINER"
    printf 'CRABBOX_SHARED_TOKEN=%s\n' "$shared_token"
    printf 'CRABBOX_ADMIN_TOKEN=%s\n' "$admin_token"
    printf 'CRABBOX_SESSION_SECRET=%s\n' "$session_secret"
    printf 'CRABBOX_SHARED_OWNER=kyber\n'
    printf 'CRABBOX_DEFAULT_ORG=personal\n'
    printf 'CRABBOX_PUBLIC_URL=https://kyber.tail950b36.ts.net:10443\n'
    printf 'CRABBOX_MAX_ACTIVE_LEASES=2\n'
    printf 'CRABBOX_MAX_ACTIVE_LEASES_PER_OWNER=1\n'
    printf 'CRABBOX_MAX_MONTHLY_USD=25\n'
    printf 'CRABBOX_MAX_MONTHLY_USD_PER_OWNER=10\n'
  } >"$GENERATED_ENV"
  chmod 600 "$GENERATED_ENV"
fi

set -a
# shellcheck source=/dev/null
. "$GENERATED_ENV"
if [ -f "$LOCAL_ENV" ]; then
  # Machine-local values override generated defaults and may add provider
  # credentials. Never print this file or its contents.
  # shellcheck source=/dev/null
  . "$LOCAL_ENV"
fi
set +a

: "${POSTGRES_PASSWORD:?POSTGRES_PASSWORD is required}"
: "${DATABASE_URL:?DATABASE_URL is required}"
: "${CRABBOX_SHARED_TOKEN:?CRABBOX_SHARED_TOKEN is required}"
: "${CRABBOX_PUBLIC_URL:?CRABBOX_PUBLIC_URL is required}"

coordinator_pid=""
docker_cleanup() {
  @docker@ stop --time 120 "$COORDINATOR_CONTAINER" >/dev/null 2>&1 || true
  @docker@ stop --time 30 "$POSTGRES_CONTAINER" >/dev/null 2>&1 || true
  if [ -n "$coordinator_pid" ]; then
    wait "$coordinator_pid" 2>/dev/null || true
  fi
}
trap docker_cleanup TERM INT EXIT

if ! @docker@ info >/dev/null 2>&1; then
  echo "Docker is not accessible" >&2
  exit 1
fi

if ! @docker@ image inspect "$POSTGRES_IMAGE" >/dev/null 2>&1; then
  @docker@ pull "$POSTGRES_IMAGE"
fi

if ! @docker@ image inspect "$IMAGE" >/dev/null 2>&1; then
  echo "Building Crabbox coordinator ${VERSION} from ${SOURCE_REVISION}..."
  @docker@ build --pull --tag "$IMAGE" "$SOURCE_CONTEXT"
fi

@docker@ network inspect "$NETWORK_NAME" >/dev/null 2>&1 ||
  @docker@ network create "$NETWORK_NAME" >/dev/null
@docker@ volume inspect crabbox-postgres-data >/dev/null 2>&1 ||
  @docker@ volume create crabbox-postgres-data >/dev/null

@docker@ rm -f "$COORDINATOR_CONTAINER" "$POSTGRES_CONTAINER" >/dev/null 2>&1 || true

@docker@ run --detach \
  --name "$POSTGRES_CONTAINER" \
  --network "$NETWORK_NAME" \
  --restart no \
  --health-cmd='pg_isready -U crabbox -d crabbox' \
  --health-interval=2s \
  --health-timeout=3s \
  --health-retries=30 \
  --env POSTGRES_USER=crabbox \
  --env POSTGRES_DB=crabbox \
  --env POSTGRES_PASSWORD \
  --mount type=volume,source=crabbox-postgres-data,target=/var/lib/postgresql/data \
  "$POSTGRES_IMAGE" >/dev/null

postgres_ready=false
for _ in $(seq 1 60); do
  if [ "$(@docker@ inspect --format '{{.State.Health.Status}}' "$POSTGRES_CONTAINER")" = "healthy" ]; then
    postgres_ready=true
    break
  fi
  sleep 1
done
if [ "$postgres_ready" != "true" ]; then
  echo "Crabbox PostgreSQL did not become healthy" >&2
  @docker@ logs --tail 50 "$POSTGRES_CONTAINER" >&2 || true
  exit 1
fi

coordinator_args=(
  run
  --name "$COORDINATOR_CONTAINER"
  --network "$NETWORK_NAME"
  --publish 127.0.0.1:8080:8080
  --env-file "$GENERATED_ENV"
)

# Forward only Crabbox and supported provider settings from the private dotenv.
# Docker arguments contain variable names, not their values.
while IFS= read -r variable_name; do
  case "$variable_name" in
  CRABBOX_* | HETZNER_TOKEN | AWS_* | AZURE_* | GCP_* | GOOGLE_* | DAYTONA_CRABBOX_KEY | DATABASE_URL)
    coordinator_args+=(--env "$variable_name")
    ;;
  esac
done < <(compgen -A variable | sort -u)

coordinator_args+=("$IMAGE")
@docker@ "${coordinator_args[@]}" &
coordinator_pid=$!

coordinator_ready=false
for _ in $(seq 1 60); do
  if @curl@ --fail --silent --show-error http://127.0.0.1:8080/v1/health >/dev/null &&
    @curl@ --fail --silent --show-error http://127.0.0.1:8080/v1/ready >/dev/null; then
    coordinator_ready=true
    break
  fi
  if ! kill -0 "$coordinator_pid" 2>/dev/null; then
    break
  fi
  sleep 1
done
if [ "$coordinator_ready" != "true" ]; then
  echo "Crabbox coordinator did not become ready" >&2
  @docker@ logs --tail 50 "$COORDINATOR_CONTAINER" >&2 || true
  exit 1
fi

echo "Crabbox coordinator ${VERSION} is ready on 127.0.0.1:8080"
wait "$coordinator_pid"
