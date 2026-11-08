#!/usr/bin/env bash
# Reclaims regenerable caches, stale agent data, scratch trees, and Docker build state.
# Worktrees, volumes, tagged images, and running containers are never touched.
set -uo pipefail

age_days="${DISK_CLEANUP_AGE_DAYS:-2}"
codex_days="${DISK_CLEANUP_CODEX_DAYS:-30}"
data="${XDG_DATA_HOME:-$HOME/.local/share}"
var_tmp="${DISK_CLEANUP_VAR_TMP:-/var/tmp}"
status=0

prune_stale_entries() {
  local dir="$1" name="${2:-*}" entry
  [ -d "$dir" ] || return 0
  while IFS= read -r -d '' entry; do
    # A long-lived npx server lazily requires files from its cache directory.
    if pgrep -f -- "$entry" >/dev/null 2>&1; then
      continue
    fi
    # A tool can keep writing inside a directory whose own mtime stays old.
    if [ -d "$entry" ] && [ -n "$(find "$entry" -newermt "-$age_days days" -print -quit 2>/dev/null)" ]; then
      continue
    fi
    # Markers for a kept directory must stay, or its owner sees a missing build.
    case "$entry" in
    *.lock | *.ready) [ -d "${entry%.*}" ] && continue ;;
    esac
    rm -rf -- "$entry" || status=1
    [ -d "$entry" ] || rm -f -- "$entry.lock" "$entry.ready"
  done < <(find "$dir" -mindepth 1 -maxdepth 1 -name "$name" -mtime +"$age_days" -print0)
}

prune_stale_entries "${npm_config_cache:-$HOME/.npm}/_npx"
prune_stale_entries "${BUN_INSTALL_CACHE_DIR:-$HOME/.bun/install/cache}"
prune_stale_entries "${TMPDIR:-/tmp}/opencode"
# Scratch trees from CI and stack-merge tooling are left behind when their
# owner is killed, and each holds a full checkout.
prune_stale_entries "${TMPDIR:-/tmp}/stack-merge-tooling"
prune_stale_entries "$var_tmp" 'ci-ship-reference-*'
prune_stale_entries "$var_tmp" 'merged-tree-*'

if [ -d "$data/opencode" ]; then
  # opencode-stable.db was superseded by opencode-v2.db and is no longer
  # written, so a fresh mtime means a host is still on the stable channel.
  find "$data/opencode" -maxdepth 1 -type f -name 'opencode-pass-*' -mtime +7 -delete || status=1
  find "$data/opencode" -maxdepth 1 -type f -name 'opencode-stable.db*' -mtime +14 -delete || status=1
fi

if [ -d "$HOME/.codex/sessions" ]; then
  find "$HOME/.codex/sessions" -type f -mtime +"$codex_days" -delete || status=1
  find "$HOME/.codex/sessions" -mindepth 1 -type d -empty -delete || status=1
fi

if [ -d "$data" ]; then
  find "$data" -maxdepth 1 -name 'atuin.bak*' -mtime +7 -exec rm -rf -- {} + || status=1
fi

if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
  docker builder prune --force --filter until=24h || status=1
  docker image prune --force || status=1
  docker container prune --force --filter until=24h || status=1
fi

df -h / || true
exit "$status"
