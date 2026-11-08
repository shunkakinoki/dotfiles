#!/usr/bin/env bash
# Reclaims regenerable caches, stale agent data, scratch trees, and Docker build state.
# Volumes, tagged images, running containers, and worktrees with unpushed or
# uncommitted work are never touched.
set -uo pipefail

age_days="${DISK_CLEANUP_AGE_DAYS:-2}"
codex_days="${DISK_CLEANUP_CODEX_DAYS:-30}"
data="${XDG_DATA_HOME:-$HOME/.local/share}"
var_tmp="${DISK_CLEANUP_VAR_TMP:-/var/tmp}"
# Orphaned scratch checkouts reach 8G each and pile up several per day.
scratch_minutes=$((${DISK_CLEANUP_SCRATCH_HOURS:-6} * 60))
status=0

prune_stale_entries() {
  local dir="$1" name="${2:-*}" minutes="${3:-$((age_days * 1440))}" mode="${4:-}" entry recent base common
  [ -d "$dir" ] || return 0
  while IFS= read -r -d '' entry; do
    # A long-lived npx server lazily requires files from its cache directory.
    if pgrep -f -- "$entry" >/dev/null 2>&1; then
      continue
    fi
    # A build can run inside a tree without naming it on its command line.
    if [ -n "$(find /proc -mindepth 2 -maxdepth 2 -name cwd \( -lname "$entry" -o -lname "$entry/*" \) -print -quit 2>/dev/null)" ]; then
      continue
    fi
    # A tool can keep writing inside a directory whose own mtime stays old.
    # A scan that fails partway cannot prove the tree is idle, so keep it.
    if [ -d "$entry" ]; then
      recent=$(find "$entry" -newermt "-$minutes minutes" -print -quit 2>/dev/null) || continue
      [ -n "$recent" ] && continue
    fi
    common=
    # Markers for a kept directory must stay, or its owner sees a missing build.
    if [ "$mode" = markers ]; then
      case "$entry" in
      *.lock | *.ready) [ -d "${entry%.*}" ] && continue ;;
      esac
    elif [ "$mode" = pushed ]; then
      [ -z "$(git -C "$entry" status --porcelain 2>/dev/null || echo dirty)" ] || continue
      # Ignored files are build output except local secrets, which exist nowhere else.
      [ -z "$(git -C "$entry" ls-files --others --ignored --exclude-standard -- ':(glob)**/.env*' 2>/dev/null || echo kept)" ] || continue
      [ -n "$(git -C "$entry" branch -r --contains HEAD 2>/dev/null)" ] || continue
      common=$(git -C "$entry" rev-parse --path-format=absolute --git-common-dir 2>/dev/null) || continue
    fi
    rm -rf -- "$entry" || status=1
    # The main repository keeps the branch checked out until its stale worktree is pruned.
    if [ -n "$common" ]; then
      git --git-dir="$common" worktree prune || status=1
    fi
    if [ "$mode" = markers ] && [ ! -d "$entry" ]; then
      base="${entry%.lock}"
      base="${base%.ready}"
      rm -f -- "$base.lock" "$base.ready"
    fi
  done < <(find "$dir" -mindepth 1 -maxdepth 1 -name "$name" -mmin +"$minutes" -print0)
}

prune_stale_entries "${npm_config_cache:-$HOME/.npm}/_npx"
prune_stale_entries "${BUN_INSTALL_CACHE_DIR:-$HOME/.bun/install/cache}"
prune_stale_entries "${TMPDIR:-/tmp}/opencode"
# Scratch trees from CI and stack-merge tooling are left behind when their
# owner is killed, and each holds a full checkout.
prune_stale_entries "${TMPDIR:-/tmp}/stack-merge-tooling" '*' "$scratch_minutes" markers
prune_stale_entries "$var_tmp" 'ci-ship-reference-*' "$scratch_minutes"
prune_stale_entries "$var_tmp" 'merged-tree-*' "$scratch_minutes"
# Codex keeps a full checkout per task and never removes it.
prune_stale_entries "$HOME/.codex/worktrees" '*' "$scratch_minutes" pushed

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
