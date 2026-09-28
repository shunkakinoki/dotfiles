#!/usr/bin/env bash
# Reclaims regenerable package and Docker build caches. Worktrees, volumes,
# tagged images, and running containers are never touched.
set -uo pipefail

age_days="${DISK_CLEANUP_AGE_DAYS:-2}"
status=0

prune_stale_entries() {
  local dir="$1" entry
  [ -d "$dir" ] || return 0
  while IFS= read -r -d '' entry; do
    # A long-lived npx server lazily requires files from its cache directory.
    if pgrep -f -- "$entry" >/dev/null 2>&1; then
      continue
    fi
    rm -rf -- "$entry" || status=1
  done < <(find "$dir" -mindepth 1 -maxdepth 1 -mtime +"$age_days" -print0)
}

prune_stale_entries "${npm_config_cache:-$HOME/.npm}/_npx"
prune_stale_entries "${BUN_INSTALL_CACHE_DIR:-$HOME/.bun/install/cache}"

if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
  docker builder prune --force --filter until=24h || status=1
  docker image prune --force || status=1
  docker container prune --force --filter until=24h || status=1
fi

df -h / || true
exit "$status"
