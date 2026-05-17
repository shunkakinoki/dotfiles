#!/usr/bin/env bash
# @beadsDir@ and @dolt@ are substituted by pkgs.replaceVars.
set -euo pipefail

mkdir -p "@beadsDir@"

if [ -d "@beadsDir@/dolt" ] && [ ! -L "@beadsDir@/dolt" ]; then
  if [ -e "@beadsDir@/df" ]; then
    echo "Refusing to migrate @beadsDir@/dolt because @beadsDir@/df already exists" >&2
    exit 1
  fi

  mv -f "@beadsDir@/dolt" "@beadsDir@/df"
fi

# External databases (e.g. another repo's .beads/<dbname>) are mounted by the
# user via plain symlinks under @beadsDir@/<dbname>. The server scans
# @beadsDir@ at startup, so each symlinked DB becomes addressable by its name.

exec "@dolt@/bin/dolt" sql-server \
  -H 127.0.0.1 \
  -P 3307 \
  --data-dir "@beadsDir@" \
  --loglevel info
