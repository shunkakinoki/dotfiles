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

  # The managed server also serves this checkout. It is outside the ghq root
  # used for additional repositories and must be provisioned on fresh hosts.
  if BEADS_SYNC_REPO_DIR="$HOME/dotfiles" BEADS_SYNC_REPO_NAME="dotfiles" BEADS_SYNC_REPO_CONTEXT="dotfiles" "$BASH" "$0" --repo; then
    :
  else
    overall_status=$?
    log "Dotfiles federation failed with status $overall_status"
  fi

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

cycle_started="$(@coreutils@/bin/date -u '+%Y-%m-%dT%H:%M:%SZ')"
# Spokes converge on the hub's remotesapi endpoint for this repository's
# database; the hub itself keeps the repository's sync.remote as the off-site
# backup. The database name is the repository's own, not the hub's.
configured_dolt_remote() {
  local database

  if [ -z "${BEADS_FEDERATION_HUB:-}" ]; then
    "$bd_cli" -C "$repo_dir" config get sync.remote 2>/dev/null || true
    return 0
  fi

  database="$(@jq@/bin/jq -er '.dolt_database | select(type == "string" and length > 0)' "$repo_dir/.beads/metadata.json" 2>/dev/null || true)"
  if [ -z "$database" ]; then
    log "Dolt database name is not recorded in .beads/metadata.json"
    return 1
  fi
  printf '%s/%s\n' "${BEADS_FEDERATION_HUB%/}" "$database"
}

configured_remote="$(configured_dolt_remote)" || exit 1
if [ -z "$configured_remote" ]; then
  log "Dolt sync remote is not configured"
  exit 1
fi
if ! "$BASH" "@ensureDatabaseScript@" "$repo_dir" "$configured_remote"; then
  log "Database provisioning failed; federation did not run"
  exit 1
fi
# Cloned history excludes Beads' node-local runtime tables. The supported
# initializer restores them and retains the remote schema migration guard.
if ! "$bd_cli" -C "$repo_dir" migrate schema --json >/dev/null 2>&1; then
  log "Beads database initialization failed; federation did not run"
  exit 1
fi
if ! "$bd_cli" -C "$repo_dir" ping >/dev/null 2>&1; then
  log "Provisioned database did not pass Beads connectivity verification"
  exit 1
fi

ensure_dolt_remote() {
  local configured_remote
  local current_remote

  configured_remote="$(configured_dolt_remote)" || return 1
  if [ -z "$configured_remote" ]; then
    log "Dolt sync remote is not configured"
    return 1
  fi

  current_remote="$("$bd_cli" -C "$repo_dir" dolt remote list 2>/dev/null | awk '$1 == "origin" { print $2; exit }')"
  if [ "$current_remote" = "$configured_remote" ]; then
    return 0
  fi

  if [ -n "$current_remote" ]; then
    log "Replacing Dolt remote origin"
    "$bd_cli" -C "$repo_dir" dolt remote remove origin >/dev/null
  fi
  log "Registering configured Dolt remote"
  "$bd_cli" -C "$repo_dir" dolt remote add origin "$configured_remote" --allow-git-origin >/dev/null
}

if ! ensure_dolt_remote; then
  log "Dolt remote setup failed"
  exit 1
fi

log "Synchronizing Dolt remote"
sync_status=0
sync_output="$(@coreutils@/bin/timeout 120 "$bd_cli" -C "$repo_dir" sync --yes 2>&1)" || sync_status=$?
if [ "$sync_status" -ne 0 ]; then
  log "Dolt sync failed with status $sync_status"
  printf '%s\n' "$sync_output" | @coreutils@/bin/tail -n 5
  exit "$sync_status"
fi

if ! "$bd_cli" -C "$repo_dir" ready --json >/dev/null 2>&1; then
  log "Federated database did not pass Beads work-discovery verification"
  exit 1
fi

@coreutils@/bin/mkdir -p "$sync_state_dir"
printf '%s\n' "$cycle_started" >"$sync_checkpoint_file.tmp"
@coreutils@/bin/mv -f "$sync_checkpoint_file.tmp" "$sync_checkpoint_file"
log "Dolt federation complete"
