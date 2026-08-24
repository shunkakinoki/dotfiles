#!/usr/bin/env bash

set -euo pipefail

bd_cli="@bd@"
dolt_cli="@dolt@/bin/dolt"
linear_cli="@linear@"
linear_workspace="@linearWorkspace@"
linear_team_id="@linearTeamId@"
linear_credentials_file="${XDG_CONFIG_HOME:-$HOME/.config}/linear/credentials.toml"
sync_state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/beads-linear-sync"

log() {
  local context=""

  if [ -n "${repo_context:-}" ]; then
    context="[$repo_context] "
  fi
  printf '[beads-linear-sync] %s%s\n' "$context" "$*"
}

# Repository scope and credentials are machine-local policy. The tracked Nix
# module never embeds checkout paths or secret dotenv values in the store.
env_file="${DOTFILES_ENV_FILE:-$HOME/dotfiles/.env}"
if [ -f "$env_file" ]; then
  set -a
  # shellcheck source=/dev/null
  . "$env_file"
  set +a
fi

# The parent process dispatches each org/repo entry through an isolated child
# so one repository cannot prevent later repositories from being attempted.
if [ "${1:-}" != "--repo" ]; then
  configured_repos="${BEADS_LINEAR_SYNC_REPOS:-}"
  if [ -z "$configured_repos" ]; then
    log "BEADS_LINEAR_SYNC_REPOS is required in the local dotenv file"
    exit 1
  fi

  IFS=',' read -r -a repo_names <<<"$configured_repos"
  declare -A seen_repo_names=()
  overall_status=0

  for repo_index in "${!repo_names[@]}"; do
    configured_repo="${repo_names[$repo_index]}"
    repo_context="repository $((repo_index + 1))/${#repo_names[@]}"
    if [ -z "$configured_repo" ]; then
      log "BEADS_LINEAR_SYNC_REPOS contains an empty repository name"
      overall_status=1
      continue
    fi
    if [[ ! $configured_repo =~ ^[A-Za-z0-9._-]+/[A-Za-z0-9._-]+$ ]]; then
      log "Invalid org/repo entry in BEADS_LINEAR_SYNC_REPOS"
      overall_status=1
      continue
    fi
    if [ -n "${seen_repo_names[$configured_repo]:-}" ]; then
      log "BEADS_LINEAR_SYNC_REPOS contains a duplicate repository entry"
      overall_status=1
      continue
    fi
    seen_repo_names[$configured_repo]=1

    repo_path="$HOME/ghq/github.com/$configured_repo"
    if BEADS_LINEAR_SYNC_REPO_DIR="$repo_path" BEADS_LINEAR_SYNC_REPO_NAME="$configured_repo" BEADS_LINEAR_SYNC_REPO_CONTEXT="$repo_context" "$BASH" "$0" --repo; then
      :
    else
      status=$?
      log "Repository sync failed with status $status"
      if [ "$overall_status" -eq 0 ]; then
        overall_status="$status"
      fi
    fi
  done

  exit "$overall_status"
fi

repo_dir="${BEADS_LINEAR_SYNC_REPO_DIR:-}"
repo_name="${BEADS_LINEAR_SYNC_REPO_NAME:-}"
repo_context="${BEADS_LINEAR_SYNC_REPO_CONTEXT:-}"
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

ensure_config() {
  local key="$1"
  local expected="$2"
  local actual

  actual="$("$bd_cli" -C "$repo_dir" config get "$key" 2>/dev/null || true)"
  if [ "$actual" != "$expected" ]; then
    "$bd_cli" -C "$repo_dir" config set "$key" "$expected" >/dev/null 2>&1
  fi
}

wait_for_beads() {
  local _attempt

  for _attempt in 1 2 3 4 5 6 7 8 9 10 11 12; do
    if "$bd_cli" -C "$repo_dir" ping >/dev/null 2>&1; then
      return 0
    fi
    @coreutils@/bin/sleep 5
  done

  log "Beads did not become ready within 60 seconds"
  return 1
}

run_linear() {
  local output
  local status

  set +e
  output="$("$@" 2>&1)"
  status=$?
  set -e

  # bd may return zero after individual API operations were rejected. Treat
  # its circuit-breaker warning as a deferred run regardless of exit status.
  if [[ $output == *"rate limit circuit breaker"* ]]; then
    return 75
  fi

  return "$status"
}

run_dolt_sql() {
  local query="$1"

  "$dolt_cli" \
    --host=127.0.0.1 \
    --port="${BEADS_DOLT_SERVER_PORT:-3307}" \
    --user="${DOLT_CLI_USER:-root}" \
    --no-tls \
    sql -q "$query" >/dev/null
}

restore_linear_last_sync() {
  if [ -z "${linear_last_sync_before_pull:-}" ]; then
    return 0
  fi
  if [[ ! $linear_last_sync_before_pull =~ ^[0-9T:.+-]+Z?$ ]]; then
    log "Refusing to restore an invalid Linear sync timestamp"
    return 1
  fi

  run_dolt_sql "USE \`$linear_database\`; REPLACE INTO local_metadata (\`key\`, value) VALUES ('linear.last_sync', '$linear_last_sync_before_pull');"
}

federate_beads() {
  local phase="$1"
  local status

  set +e
  @coreutils@/bin/timeout 120 "$bd_cli" -C "$repo_dir" sync --yes >/dev/null 2>&1
  status=$?
  set -e

  if [ "$status" -ne 0 ]; then
    log "Dolt $phase federation failed with status $status"
    return "$status"
  fi
}

if [ -z "${LINEAR_API_KEY:-}" ] && [ -f "$linear_credentials_file" ] && [ ! -L "$linear_credentials_file" ]; then
  @coreutils@/bin/chmod 600 "$linear_credentials_file"
  LINEAR_API_KEY="$(@gawk@/bin/awk -F '[[:space:]]*=[[:space:]]*' -v workspace="$linear_workspace" '
    $1 == workspace {
      value = $2
      sub(/^"/, "", value)
      sub(/"$/, "", value)
      print value
      exit
    }
  ' "$linear_credentials_file")"
fi

if [ -z "${LINEAR_API_KEY:-}" ]; then
  LINEAR_API_KEY="$(@coreutils@/bin/timeout 10 @coreutils@/bin/env -u LINEAR_API_KEY "$linear_cli" auth token --workspace "$linear_workspace" 2>/dev/null || true)"
fi

if [ -z "${LINEAR_API_KEY:-}" ]; then
  log "No Linear credential is available from the environment or Linear CLI"
  exit 1
fi

export LINEAR_API_KEY
export LINEAR_TEAM_ID="${LINEAR_TEAM_ID:-$linear_team_id}"

wait_for_beads
@coreutils@/bin/mkdir -p "$sync_state_dir"
cycle_started="$(@coreutils@/bin/date -u '+%Y-%m-%dT%H:%M:%SZ')"

# Linear requires an explicit inbound type map and an explicit outbound state
# name when a workflow has multiple states of the same type (for example,
# "In Progress" and "In Review"). Commit this contract before pulling because
# Beads deliberately refuses to auto-commit internal config keys during sync.
ensure_config linear.state_map.triage open
ensure_config linear.state_map.backlog open
ensure_config linear.state_map.unstarted open
ensure_config linear.state_map.started in_progress
ensure_config linear.state_map.completed closed
ensure_config linear.state_map.canceled closed
ensure_config linear.state_map.duplicate closed
ensure_config linear.outbound_state_map.open Todo
ensure_config linear.outbound_state_map.in_progress "In Progress"
ensure_config linear.outbound_state_map.closed Done
"$bd_cli" -C "$repo_dir" dolt commit -m "chore(beads): configure Linear sync" >/dev/null 2>&1

# Kyber is the only Linear writer. Require federation first so Linear never
# reconciles from a replica that could not ingest the shared Dolt state.
federate_beads "pre-sync"

linear_status="$("$bd_cli" -C "$repo_dir" linear status --json)"
if [ -s "$sync_checkpoint_file" ]; then
  previous_sync="$(<"$sync_checkpoint_file")"
else
  previous_sync="$(@jq@/bin/jq -r '.last_sync // ""' <<<"$linear_status")"
fi

# Beads' incremental pull currently performs one dolt_history_issues query for
# every pre-linked issue. At this repository's scale that path exceeds the
# bounded service window, while a complete tracker fetch finishes promptly.
# Clear only Kyber's ignored clone-local cursor before pulling; the successful
# pull writes a fresh cursor, and failures restore the prior value.
linear_database="$(@jq@/bin/jq -r '.dolt_database // empty' "$repo_dir/.beads/metadata.json")"
if [[ ! $linear_database =~ ^[A-Za-z0-9_]+$ ]]; then
  log "Beads metadata does not contain a valid Dolt database name"
  exit 1
fi
linear_last_sync_before_pull="$(@jq@/bin/jq -r '.last_sync // ""' <<<"$linear_status")"
run_dolt_sql "USE \`$linear_database\`; DELETE FROM local_metadata WHERE \`key\` = 'linear.last_sync';"

# Pull open and closed Linear work so cancels/Done land in Beads. A rate-limit
# failure is deferred to the next scheduled run instead of making launchd
# hot-loop a failed job.
log "Pulling complete Linear state"
if run_linear @coreutils@/bin/timeout 720 "$bd_cli" -C "$repo_dir" linear sync \
  --pull \
  --state all \
  --relations \
  --no-wait; then
  :
else
  status=$?
  restore_linear_last_sync
  if [ "$status" -eq 75 ]; then
    log "Linear pull deferred; the next 900-second run will retry"
    exit 0
  fi
  log "Linear pull failed with status $status"
  exit "$status"
fi

all_issues="$("$bd_cli" -C "$repo_dir" list --all --json --limit 0 --skip-labels)"
changed_ids="$(@jq@/bin/jq -r --arg previous_sync "$previous_sync" '
  (if type == "object" and has("issues") then .issues else . end)
  | [
    .[]
    | select(
        if .status == "closed" then
          $previous_sync != ""
          and .updated_at >= $previous_sync
          and ((.external_ref // "") | contains("linear.app"))
        else
          $previous_sync == ""
          or .updated_at >= $previous_sync
          or ((.external_ref // "") | contains("linear.app") | not)
        end
      )
    | .id
  ]
  | join(",")
' <<<"$all_issues")"

# Push only the active local delta since the previous successful pull. Bound
# each batch so a large first run makes durable progress without pinning the
# recurring service on one API call.
if [ -n "$changed_ids" ]; then
  push_batch_size=10
  IFS=',' read -r -a changed_id_array <<<"$changed_ids"
  push_batch_count=$(((${#changed_id_array[@]} + push_batch_size - 1) / push_batch_size))

  for ((batch_start = 0; batch_start < ${#changed_id_array[@]}; batch_start += push_batch_size)); do
    batch_number=$((batch_start / push_batch_size + 1))
    batch_ids="$(
      IFS=,
      printf '%s' "${changed_id_array[*]:batch_start:push_batch_size}"
    )"
    log "Pushing changed active Beads batch $batch_number/$push_batch_count"

    if run_linear @coreutils@/bin/timeout 120 "$bd_cli" -C "$repo_dir" linear sync --push --issues "$batch_ids" --no-wait; then
      :
    else
      status=$?
      if [ "$status" -eq 75 ]; then
        log "Linear push deferred; the next 900-second run will retry"
        exit 0
      fi
      log "Linear push failed with status $status"
      exit "$status"
    fi
  done
else
  log "No changed active Beads to push"
fi

"$bd_cli" -C "$repo_dir" dolt commit -m "chore(beads): sync Linear" >/dev/null 2>&1
federate_beads "post-sync"

printf '%s\n' "$cycle_started" >"$sync_checkpoint_file.tmp"
@coreutils@/bin/mv -f "$sync_checkpoint_file.tmp" "$sync_checkpoint_file"

"$bd_cli" -C "$repo_dir" linear status --json
