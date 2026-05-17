#!/usr/bin/env bash
# @beadsDir@ and @dolt@ are substituted by pkgs.replaceVars.
set -euo pipefail

mkdir -p "@beadsDir@"

# Legacy migration: a `dolt` directory predates the rename to `df`.
# Only migrate when `df` does not exist yet; once `df` is in place the
# `dolt` directory is treated as its own (possibly external) database.
if [ -d "@beadsDir@/dolt" ] && [ ! -L "@beadsDir@/dolt" ] && [ ! -e "@beadsDir@/df" ]; then
  mv -f "@beadsDir@/dolt" "@beadsDir@/df"
fi

# Additional databases (e.g. data shared with another repo) are managed by
# the user as real directories under @beadsDir@/<dbname>. dolt sql-server
# scans @beadsDir@ at startup and exposes each subdirectory as a database
# by that name.

exec "@dolt@/bin/dolt" sql-server \
  -H 127.0.0.1 \
  -P 3307 \
  --data-dir "@beadsDir@" \
  --loglevel info
