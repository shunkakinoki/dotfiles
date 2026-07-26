#!/usr/bin/env bash
# @beadsDir@, @legacyBeadsDir@, and @dolt@ are substituted by pkgs.replaceVars.
set -euo pipefail

mkdir -p "@beadsDir@"

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

exec "@dolt@/bin/dolt" sql-server \
  -H 127.0.0.1 \
  -P 3307 \
  --data-dir "@beadsDir@" \
  --loglevel info
