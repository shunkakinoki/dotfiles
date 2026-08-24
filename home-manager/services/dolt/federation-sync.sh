#!/usr/bin/env bash

set -euo pipefail

bd_cli="@bd@"
sync_state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/beads-federation-sync"

log() {
  local context=""

  if [ -n "${repo_context:-}" ]; then
    context="[$repo_context] "
  fi
  printf '[beads-federation-sync] %s%s\n' "$context" "$*"
}

# Repository scope is machine-local policy. Keep real org/repo identifiers in
# the untracked dotenv file, never in the Nix store or tracked configuration.
env_file="${DOTFILES_ENV_FILE:-$HOME/dotfiles/.env}"
if [ -f "$env_file" ]; then
  set -a
  # shellcheck source=/dev/null
  . "$env_file"
  set +a
fi

if [ "${1:-}" != "--repo" ]; then
  configured_repos="${BEADS_SYNC_REPOS:-${BEADS_LINEAR_SYNC_REPOS:-}}"
  if [ -z "$configured_repos" ]; then
    log "BEADS_SYNC_REPOS is required in the local dotenv file"
    exit 1
  fi

  IFS=',' read -r -a repo_names <<<"$configured_repos"
  declare -A seen_repo_names=()
  overall_status=0

  for repo_index in "${!repo_names[@]}"; do
    configured_repo="${repo_names[$repo_index]}"
    repo_context="repository $((repo_index + 1))/${#repo_names[@]}"
    if [ -z "$configured_repo" ]; then
      log "BEADS_SYNC_REPOS contains an empty repository name"
      overall_status=1
      continue
    fi
    if [[ ! $configured_repo =~ ^[A-Za-z0-9._-]+/[A-Za-z0-9._-]+$ ]]; then
      log "Invalid org/repo entry in BEADS_SYNC_REPOS"
      overall_status=1
      continue
    fi
    if [ -n "${seen_repo_names[$configured_repo]:-}" ]; then
      log "BEADS_SYNC_REPOS contains a duplicate repository entry"
      overall_status=1
      continue
    fi
    seen_repo_names[$configured_repo]=1

    repo_path="$HOME/ghq/github.com/$configured_repo"
    if BEADS_SYNC_REPO_DIR="$repo_path" BEADS_SYNC_REPO_NAME="$configured_repo" BEADS_SYNC_REPO_CONTEXT="$repo_context" "$BASH" "$0" --repo; then
      :
    else
      status=$?
      log "Repository federation failed with status $status"
      if [ "$overall_status" -eq 0 ]; then
        overall_status="$status"
      fi
    fi
  done

  exit "$overall_status"
fi

repo_dir="${BEADS_SYNC_REPO_DIR:-}"
repo_name="${BEADS_SYNC_REPO_NAME:-}"
repo_context="${BEADS_SYNC_REPO_CONTEXT:-}"
if [ -z "$repo_dir" ] || [ -z "$repo_name" ] || [ -z "$repo_context" ]; then
  log "Internal repository dispatch is incomplete"
  exit 1
fi

if [ ! -d "$repo_dir" ] || [ ! -e "$repo_dir/.beads" ]; then
  log "Configured checkout is not a Beads repository"
  exit 1
fi

repo_dir="$(cd "$repo_dir" && pwd -P)"
repo_slug="$repo_name"
repo_slug="${repo_slug//\//_}"
repo_slug="${repo_slug//[^[:alnum:]_.-]/_}"
sync_checkpoint_file="$sync_state_dir/last-success-$repo_slug"

for _attempt in 1 2 3 4 5 6 7 8 9 10 11 12; do
  if "$bd_cli" -C "$repo_dir" ping >/dev/null 2>&1; then
    break
  fi
  if [ "$_attempt" -eq 12 ]; then
    log "Beads did not become ready within 60 seconds"
    exit 1
  fi
  @coreutils@/bin/sleep 5
done

cycle_started="$(@coreutils@/bin/date -u '+%Y-%m-%dT%H:%M:%SZ')"
log "Synchronizing Dolt remote"
@coreutils@/bin/timeout 120 "$bd_cli" -C "$repo_dir" sync --yes >/dev/null 2>&1

@coreutils@/bin/mkdir -p "$sync_state_dir"
printf '%s\n' "$cycle_started" >"$sync_checkpoint_file.tmp"
@coreutils@/bin/mv -f "$sync_checkpoint_file.tmp" "$sync_checkpoint_file"
log "Dolt federation complete"
