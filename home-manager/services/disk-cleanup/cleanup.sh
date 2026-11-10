#!/usr/bin/env bash
# Reclaims regenerable caches, scratch trees, and Docker build state.
# Volumes, images used in the last week, running containers, and worktrees with
# unpushed or uncommitted work are never touched.
set -uo pipefail

age_days="${DISK_CLEANUP_AGE_DAYS:-1}"
var_tmp="${DISK_CLEANUP_VAR_TMP:-/var/tmp}"
# Orphaned scratch checkouts reach 8G each and pile up several per day.
scratch_minutes=$((${DISK_CLEANUP_SCRATCH_HOURS:-1} * 60))
status=0

# macOS has no /proc; a process can use a tree without naming it in argv.
# If its cwd inventory cannot be read, leave all entries in place.
platform=$(uname -s)
process_cwds=
if [ "$platform" = Darwin ]; then
  process_cwds=$(lsof -nP -a -d cwd -Fn 2>/dev/null) || exit 1
fi

has_live_cwd() {
  local entry="$1" cwd
  if [ "$platform" = Darwin ]; then
    while IFS= read -r cwd; do
      case "$cwd" in
      "n$entry" | "n$entry/"*) return 0 ;;
      esac
    done <<<"$process_cwds"
    return 1
  fi
  [ -n "$(find /proc -mindepth 2 -maxdepth 2 -name cwd \( -lname "$entry" -o -lname "$entry/*" \) -print -quit 2>/dev/null)" ]
}

prune_stale_entries() {
  local dir="$1" name="${2:-*}" minutes="${3:-$((age_days * 1440))}" mode="${4:-}" entry recent base common
  [ -d "$dir" ] || return 0
  while IFS= read -r -d '' entry; do
    # A long-lived npx server lazily requires files from its cache directory.
    # pgrep reads its pattern as a regex, so path characters like . and + must be literal.
    if pgrep -f -- "$(printf '%s' "$entry" | sed 's/[][\.*^$+?(){}|]/\\&/g')" >/dev/null 2>&1; then
      continue
    fi
    # A build can run inside a tree without naming it on its command line.
    if has_live_cwd "$entry"; then
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
# PR follow-through and queue verification leave a full checkout per run, and
# the worktree cache is rebuilt on demand.
for pattern in 'pr-followthrough-*' 'queue-head-*' 'queue-base*' 'worktree-cache'; do
  prune_stale_entries "${TMPDIR:-/tmp}" "$pattern" "$scratch_minutes"
done
prune_stale_entries "$var_tmp" 'worktree-cache' "$scratch_minutes"
# Codex keeps a full checkout per task and never removes it.
prune_stale_entries "$HOME/.codex/worktrees" '*' "$scratch_minutes" pushed
# T3 leaves one checkout per task under <root>/<repo>/<name>, and paused tasks
# resume within days, so only pushed trees idle that long go. Herdr worktrees
# are left to the fleet's herdr-worktree-gc, which also checks open PRs.
for repo in "$HOME/.t3/worktrees"/*/; do
  prune_stale_entries "${repo%/}" '*' "$((age_days * 1440))" pushed
done

# Session databases, transcripts, and shell-history backups are durable data.
# Their age never authorizes this cache cleaner to delete them.

if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
  docker builder prune --force --filter until=24h || status=1
  docker image prune --all --force --filter until=168h || status=1
  docker container prune --force --filter until=24h || status=1
fi

df -h / || true
exit "$status"
