#!/usr/bin/env bash

set -euo pipefail

bd_cli="@bd@"
dolt_cli="@dolt@/bin/dolt"
linear_cli="@linear@"
linear_workspace="@linearWorkspace@"
linear_team_id="@linearTeamId@"
linear_credentials_file="${XDG_CONFIG_HOME:-$HOME/.config}/linear/credentials.toml"
sync_state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/beads-linear-sync"
federation_timeout_seconds=360
federation_fsck_timeout=300s

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

# An accepted issue completes through the same repository lock and credential
# boundary as the periodic reconciler. The close reason is read from stdin so
# evidence never appears in the process arguments.
if [ "${1:-}" = "--complete" ]; then
  configured_repo="${2:-}"
  bead_id="${3:-}"
  if [ "$#" -ne 3 ] || [[ ! $configured_repo =~ ^[A-Za-z0-9._-]+/[A-Za-z0-9._-]+$ ]]; then
    log "Usage: beads-linear-complete org/repo bead-id < close-reason"
    exit 64
  fi
  if [[ ! $bead_id =~ ^[A-Za-z0-9._-]+$ ]]; then
    log "Invalid Bead ID"
    exit 64
  fi

  repo_path="$HOME/ghq/github.com/$configured_repo"
  BEADS_LINEAR_SYNC_REPO_DIR="$repo_path" \
    BEADS_LINEAR_SYNC_REPO_NAME="$configured_repo" \
    BEADS_LINEAR_SYNC_REPO_CONTEXT="acceptance completion" \
    "$BASH" "$0" --repo --complete "$bead_id"
  exit
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
operation="${2:---sync}"
completion_bead_id="${3:-}"
if [ -z "$repo_dir" ] || [ -z "$repo_name" ] || [ -z "$repo_context" ]; then
  log "Internal repository dispatch is incomplete"
  exit 1
fi

if [ ! -d "$repo_dir" ] || [ ! -e "$repo_dir/.beads" ]; then
  log "Configured checkout is not a Beads repository"
  exit 1
fi

repo_dir="$(cd "$repo_dir" && pwd -P)"
# Percent is excluded by the validated org/repo alphabet, so this encoding is
# injective even when either repository segment contains underscores.
repo_slug="${repo_name//\//%2F}"
sync_checkpoint_file="$sync_state_dir/last-success-$repo_slug"
reconciliation_lock_file="$sync_state_dir/reconcile-$repo_slug.lock"

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

push_issue_batches() {
  local issue_ids="$1"
  local description="$2"
  local batch_size=10
  local batch_count
  local batch_ids
  local batch_number
  local batch_start
  local status
  local -a issue_id_array

  if [ -z "$issue_ids" ]; then
    log "No $description Beads to push"
    return 0
  fi

  IFS=',' read -r -a issue_id_array <<<"$issue_ids"
  batch_count=$(((${#issue_id_array[@]} + batch_size - 1) / batch_size))
  for ((batch_start = 0; batch_start < ${#issue_id_array[@]}; batch_start += batch_size)); do
    batch_number=$((batch_start / batch_size + 1))
    batch_ids="$(
      IFS=,
      printf '%s' "${issue_id_array[*]:batch_start:batch_size}"
    )"
    log "Pushing $description Beads batch $batch_number/$batch_count"

    if run_linear @coreutils@/bin/timeout 120 "$bd_cli" -C "$repo_dir" linear sync --push --issues "$batch_ids" --no-wait; then
      :
    else
      status=$?
      if [ "$status" -eq 75 ]; then
        log "Linear push deferred; the next 900-second run will retry"
        return 75
      fi
      log "Linear push failed with status $status"
      return "$status"
    fi
  done
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
  @coreutils@/bin/timeout "$federation_timeout_seconds" \
    @coreutils@/bin/env BEADS_FSCK_TIMEOUT="$federation_fsck_timeout" \
    "$bd_cli" -C "$repo_dir" sync --yes >/dev/null 2>&1
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
if [[ $LINEAR_API_KEY == *$'\n'* ]] || [[ $LINEAR_API_KEY == *$'\r'* ]]; then
  log "Linear credential contains an invalid line break"
  exit 65
fi

wait_for_beads
@coreutils@/bin/mkdir -p "$sync_state_dir"
exec 9>"$reconciliation_lock_file"
if ! @utilLinux@/bin/flock -w 900 9; then
  log "Timed out waiting for the repository reconciliation lock"
  exit 75
fi
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

if [ "$operation" = "--complete" ]; then
  if [ -z "$completion_bead_id" ]; then
    log "Internal completion dispatch is incomplete"
    exit 64
  fi

  completion_reason="$(@coreutils@/bin/cat)"
  if [ -z "${completion_reason//[[:space:]]/}" ]; then
    log "Acceptance completion requires a close reason on stdin"
    exit 64
  fi

  federate_beads "pre-completion"
  completion_issue="$("$bd_cli" -C "$repo_dir" show "$completion_bead_id" --json)"
  completion_status="$(@jq@/bin/jq -r '.[0].status // empty' <<<"$completion_issue")"
  completion_assignee="$(@jq@/bin/jq -r '.[0].assignee // empty' <<<"$completion_issue")"
  completion_ref="$(@jq@/bin/jq -r '.[0].external_ref // empty' <<<"$completion_issue")"
  if [ -z "$completion_status" ]; then
    log "Completion Bead was not found"
    exit 66
  fi

  completion_reference_pending=0
  if [[ ! $completion_ref =~ /issue/([A-Z][A-Z0-9]*-[0-9]+)/ ]]; then
    # The marker is Beads-owned durable state, not a machine-local retry file.
    # It lets the periodic sole writer recover a rate-limited first publish
    # without selecting every unrelated locally closed Bead.
    "$bd_cli" -C "$repo_dir" update "$completion_bead_id" \
      --set-metadata linear_completion_pending=true >/dev/null
    completion_reference_pending=1
  fi

  if [ "$completion_status" != "closed" ]; then
    close_command=("$bd_cli" -C "$repo_dir")
    if [ -n "$completion_assignee" ]; then
      close_command+=(--actor "$completion_assignee")
    fi
    close_command+=(close "$completion_bead_id" --reason-file -)
    printf '%s\n' "$completion_reason" | "${close_command[@]}" >/dev/null
  fi

  # Durably federate the terminal Bead before any Linear request. If the API
  # is unavailable, the periodic closed-first pass can retry without an
  # inbound pull ever reviving the issue.
  "$bd_cli" -C "$repo_dir" dolt commit -m "chore(beads): record accepted completion" >/dev/null 2>&1
  federate_beads "accepted completion"

  if push_issue_batches "$completion_bead_id" "accepted"; then
    :
  else
    status=$?
    if [ "$status" -eq 75 ]; then
      exit 75
    fi
    exit "$status"
  fi

  completion_issue="$("$bd_cli" -C "$repo_dir" show "$completion_bead_id" --json)"
  completion_ref="$(@jq@/bin/jq -r '.[0].external_ref // empty' <<<"$completion_issue")"
  if [[ ! $completion_ref =~ /issue/([A-Z][A-Z0-9]*-[0-9]+)/ ]]; then
    log "Accepted Bead does not have a Linear issue reference after push"
    exit 65
  fi
  linear_identifier="${BASH_REMATCH[1]}"

  if [ "$completion_reference_pending" -eq 1 ]; then
    "$bd_cli" -C "$repo_dir" update "$completion_bead_id" \
      --unset-metadata linear_completion_pending >/dev/null
  fi

  # The push may have created the Linear reference. Federate that address
  # before verification so a verifier outage cannot cause a later duplicate.
  "$bd_cli" -C "$repo_dir" dolt commit -m "chore(beads): persist Linear completion" >/dev/null 2>&1
  federate_beads "post-completion push"

  linear_query="$(@jq@/bin/jq -nc --arg id "$linear_identifier" '{
    query: "query IssueState($id: String!) { issue(id: $id) { identifier state { type } } }",
    variables: {id: $id}
  }')"
  if ! linear_issue="$(@coreutils@/bin/timeout 30 @curl@/bin/curl \
    --silent \
    --show-error \
    --fail-with-body \
    --config <(
      printf 'url = "https://api.linear.app/graphql"\n'
      printf 'header = "Authorization: %s"\n' "$LINEAR_API_KEY"
      printf 'header = "Content-Type: application/json"\n'
    ) \
    --data-binary @- <<<"$linear_query")"; then
    log "Unable to verify the accepted Linear issue"
    exit 69
  fi
  if ! linear_state_type="$(@jq@/bin/jq -er '
    if ((.errors // []) | length) == 0 and .data.issue != null then
      .data.issue.state.type
    else
      empty
    end
  ' <<<"$linear_issue")"; then
    log "Linear completion verification returned no issue state"
    exit 69
  fi
  if [ "$linear_state_type" != "completed" ]; then
    log "Accepted Linear issue is not in its completed state"
    exit 70
  fi

  log "Accepted Bead and Linear issue are both terminal"
  exit 0
fi

if [ "$operation" != "--sync" ]; then
  log "Unknown reconciliation operation"
  exit 64
fi

# Kyber is the only Linear writer. Require federation first so Linear never
# reconciles from a replica that could not ingest the shared Dolt state.
federate_beads "pre-sync"

linear_status="$("$bd_cli" -C "$repo_dir" linear status --json)"
if [ -s "$sync_checkpoint_file" ]; then
  previous_sync="$(<"$sync_checkpoint_file")"
else
  previous_sync="$(@jq@/bin/jq -r '.last_sync // ""' <<<"$linear_status")"
fi

# Terminal Beads are authoritative after acceptance. Publish them before the
# full inbound refresh so a stale active Linear record can never win during
# the timer-latency window. On an initial run, publish every linked terminal
# record once; later runs use the successful-cycle checkpoint.
issues_before_pull="$("$bd_cli" -C "$repo_dir" list --all --json --limit 0 --skip-labels)"
closed_ids="$(@jq@/bin/jq -r --arg previous_sync "$previous_sync" '
  (if type == "object" and has("issues") then .issues else . end)
  | [
    .[]
    | select(
        .status == "closed"
        and (
          (.metadata.linear_completion_pending // false) == true
          or (.metadata.linear_completion_pending // false) == "true"
          or (
            ((.external_ref // "") | contains("linear.app"))
            and ($previous_sync == "" or .updated_at >= $previous_sync)
          )
        )
      )
    | .id
  ]
  | join(",")
' <<<"$issues_before_pull")"
pending_completion_ids="$(@jq@/bin/jq -r '
  (if type == "object" and has("issues") then .issues else . end)
  | [
    .[]
    | select(
        .status == "closed"
        and (
          (.metadata.linear_completion_pending // false) == true
          or (.metadata.linear_completion_pending // false) == "true"
        )
      )
    | .id
  ]
  | join(",")
' <<<"$issues_before_pull")"

if push_issue_batches "$closed_ids" "terminal"; then
  :
else
  status=$?
  if [ "$status" -eq 75 ]; then
    exit 0
  fi
  exit "$status"
fi

if [ -n "$pending_completion_ids" ]; then
  IFS=',' read -r -a pending_completion_id_array <<<"$pending_completion_ids"
  recovered_pending_id_array=()
  unresolved_pending_completion=0
  for pending_completion_id in "${pending_completion_id_array[@]}"; do
    pending_completion_issue="$("$bd_cli" -C "$repo_dir" show "$pending_completion_id" --json)"
    pending_completion_ref="$(@jq@/bin/jq -r '.[0].external_ref // empty' <<<"$pending_completion_issue")"
    if [[ $pending_completion_ref =~ /issue/([A-Z][A-Z0-9]*-[0-9]+)/ ]]; then
      recovered_pending_id_array+=("$pending_completion_id")
    else
      unresolved_pending_completion=1
      log "Pending completion does not have a Linear issue reference after push"
    fi
  done

  if [ "${#recovered_pending_id_array[@]}" -gt 0 ]; then
    "$bd_cli" -C "$repo_dir" update "${recovered_pending_id_array[@]}" \
      --unset-metadata linear_completion_pending >/dev/null
    "$bd_cli" -C "$repo_dir" dolt commit -m "chore(beads): persist recovered Linear completion" >/dev/null 2>&1
    federate_beads "post-terminal push"
  fi
  if [ "$unresolved_pending_completion" -eq 1 ]; then
    exit 65
  fi
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
changed_active_ids="$(@jq@/bin/jq -r --arg previous_sync "$previous_sync" '
  (if type == "object" and has("issues") then .issues else . end)
  | [
    .[]
    | select(
        .status != "closed"
        and (
          $previous_sync == ""
          or .updated_at >= $previous_sync
          or ((.external_ref // "") | contains("linear.app") | not)
        )
      )
    | .id
  ]
  | join(",")
' <<<"$all_issues")"

# Push only the active local delta after inbound reconciliation. Terminal
# issues never enter this phase because they were made durable before pull.
if push_issue_batches "$changed_active_ids" "changed active"; then
  :
else
  status=$?
  if [ "$status" -eq 75 ]; then
    exit 0
  fi
  exit "$status"
fi

"$bd_cli" -C "$repo_dir" dolt commit -m "chore(beads): sync Linear" >/dev/null 2>&1
federate_beads "post-sync"

printf '%s\n' "$cycle_started" >"$sync_checkpoint_file.tmp"
@coreutils@/bin/mv -f "$sync_checkpoint_file.tmp" "$sync_checkpoint_file"

"$bd_cli" -C "$repo_dir" linear status --json
