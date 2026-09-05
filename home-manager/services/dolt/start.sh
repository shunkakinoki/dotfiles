#!/usr/bin/env bash
# @beadsDir@, @legacyBeadsDir@, and @dolt@ are substituted by pkgs.replaceVars.
set -euo pipefail

listen_host="${BEADS_DOLT_LISTEN_HOST:-127.0.0.1}"
incoming_df="@beadsDir@-incoming/df"
retired_df="@beadsDir@-retired/df"

mkdir -p "@beadsDir@"

# Adopt a fully copied replacement while the old sql-server process is down.
# Home Manager restarts this service during activation, so both renames happen
# on one filesystem before the replacement server accepts any connections.
if [ -d "$incoming_df/.dolt" ]; then
  if [ -e "$retired_df" ]; then
    echo "Refusing Dolt cutover: $retired_df already exists" >&2
    exit 1
  fi

  mkdir -p "@beadsDir@-retired"
  if [ -e "@beadsDir@/df" ]; then
    mv -f -- "@beadsDir@/df" "$retired_df"
  fi
  mv -f -- "$incoming_df" "@beadsDir@/df"
fi

# Move databases served by the pre-shared-server configuration into the
# canonical root. Existing destinations win, so activation never overwrites a
# newer clone. A legacy database named `dolt` was the old name for `df`.
for legacy_db in "@legacyBeadsDir@"/*; do
  if [ ! -d "$legacy_db/.dolt" ] || [ -L "$legacy_db" ]; then
    continue
  fi

  db_name="${legacy_db##*/}"
  target_name="$db_name"
  if [ "$db_name" = "dolt" ] && [ ! -e "@beadsDir@/df" ]; then
    target_name="df"
  fi

  if [ -e "@beadsDir@/$target_name" ]; then
    continue
  fi

  mv -f -- "$legacy_db" "@beadsDir@/$target_name"
done

# Additional databases (e.g. data shared with another repo) are managed by
# the user as real directories under @beadsDir@/<dbname>. dolt sql-server
# scans @beadsDir@ at startup and exposes each subdirectory as a database
# by that name.

server_args=(
  -H "$listen_host"
  -P 3307
  --data-dir "@beadsDir@"
  --loglevel info
)

# Never expose the live working database as a push receiver: incoming pushes
# discard ignored, clone-local tables. A separate federation mirror receives
# committed history; Beads pulls it while retaining its local working tables.

exec "@dolt@/bin/dolt" sql-server "${server_args[@]}"
