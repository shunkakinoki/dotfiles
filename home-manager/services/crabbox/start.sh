#!/usr/bin/env bash
set -euo pipefail
shopt -s extglob

COORDINATOR_BIN="@coordinatorBin@"
CONFIG_DIR="@homeDir@/.config/crabbox/coordinator"
GENERATED_ENV="$CONFIG_DIR/generated.env"
LOCAL_ENV="@homeDir@/dotfiles/.env"
POSTGRES_PORT="@postgresPort@"
SOCKET_DIR="@socketDir@"

if [ ! -x "$COORDINATOR_BIN" ]; then
  echo "Crabbox coordinator is not built: $COORDINATOR_BIN" >&2
  echo "Run 'ulb crabbox' before starting the service." >&2
  exit 1
fi

mkdir -p "$CONFIG_DIR"
chmod 700 "$CONFIG_DIR"

if [ ! -s "$GENERATED_ENV" ]; then
  temp_env="$("@coreutils@/bin/mktemp" "$CONFIG_DIR/generated.env.XXXXXX")"
  trap 'rm -f "$temp_env"' EXIT
  {
    printf 'POSTGRES_PASSWORD=%s\n' "$("@openssl@/bin/openssl" rand -hex 32)"
    printf 'CRABBOX_SHARED_TOKEN=%s\n' "$("@openssl@/bin/openssl" rand -hex 32)"
    printf 'CRABBOX_ADMIN_TOKEN=%s\n' "$("@openssl@/bin/openssl" rand -hex 32)"
    printf 'CRABBOX_SESSION_SECRET=%s\n' "$("@openssl@/bin/openssl" rand -hex 32)"
  } >"$temp_env"
  chmod 600 "$temp_env"
  mv -f "$temp_env" "$GENERATED_ENV"
  trap - EXIT
fi

set -a
# shellcheck source=/dev/null
. "$GENERATED_ENV"
if [ -f "$LOCAL_ENV" ]; then
  # shellcheck source=/dev/null
  . "$LOCAL_ENV"
fi
set +a

if [[ ${POSTGRES_PASSWORD:-} != +([[:alnum:]]) ]]; then
  echo "POSTGRES_PASSWORD must contain only letters and digits" >&2
  exit 1
fi

for _ in $("@coreutils@/bin/seq" 1 60); do
  if "@postgresql_18@/bin/pg_isready" --host="$SOCKET_DIR" --port="$POSTGRES_PORT" --quiet; then
    break
  fi
  "@coreutils@/bin/sleep" 1
done

if ! "@postgresql_18@/bin/pg_isready" --host="$SOCKET_DIR" --port="$POSTGRES_PORT" --quiet; then
  echo "Crabbox PostgreSQL did not become ready" >&2
  exit 1
fi

if ! "@postgresql_18@/bin/psql" --host="$SOCKET_DIR" --port="$POSTGRES_PORT" --dbname=postgres --tuples-only --no-align --command="SELECT 1 FROM pg_roles WHERE rolname = 'crabbox'" | "@gnugrep@/bin/grep" -qx 1; then
  "@postgresql_18@/bin/createuser" --host="$SOCKET_DIR" --port="$POSTGRES_PORT" --login crabbox
fi
"@postgresql_18@/bin/psql" --host="$SOCKET_DIR" --port="$POSTGRES_PORT" --dbname=postgres --command="ALTER ROLE crabbox WITH LOGIN PASSWORD '$POSTGRES_PASSWORD'" >/dev/null

if ! "@postgresql_18@/bin/psql" --host="$SOCKET_DIR" --port="$POSTGRES_PORT" --dbname=postgres --tuples-only --no-align --command="SELECT 1 FROM pg_database WHERE datname = 'crabbox'" | "@gnugrep@/bin/grep" -qx 1; then
  "@postgresql_18@/bin/createdb" --host="$SOCKET_DIR" --port="$POSTGRES_PORT" --owner=crabbox crabbox
fi

export DATABASE_URL="postgresql://crabbox:${POSTGRES_PASSWORD}@127.0.0.1:${POSTGRES_PORT}/crabbox?sslmode=disable"
export PORT="@coordinatorPort@"
export CRABBOX_PUBLIC_URL="${CRABBOX_PUBLIC_URL:-https://kyber.tail950b36.ts.net:10443}"
export CRABBOX_SHARED_OWNER="${CRABBOX_SHARED_OWNER:-kyber}"
export CRABBOX_DEFAULT_ORG="${CRABBOX_DEFAULT_ORG:-personal}"
export CRABBOX_MAX_ACTIVE_LEASES="${CRABBOX_MAX_ACTIVE_LEASES:-4}"
export CRABBOX_MAX_ACTIVE_LEASES_PER_OWNER="${CRABBOX_MAX_ACTIVE_LEASES_PER_OWNER:-2}"
export CRABBOX_MAX_ACTIVE_LEASES_PER_ORG="${CRABBOX_MAX_ACTIVE_LEASES_PER_ORG:-4}"

exec "$COORDINATOR_BIN"
