#!/usr/bin/env bash

set -euo pipefail

bd_cli="@bd@"
dolt_cli="@dolt@/bin/dolt"
linear_cli="@linear@"
linear_workspace="@linearWorkspace@"
linear_team_id="@linearTeamId@"
linear_credentials_file="${XDG_CONFIG_HOME:-$HOME/.config}/linear/credentials.toml"
# Linear rejects an issue body over 250,000 characters with a generic
# "Argument Validation Error", which bd surfaces as a per-issue warning rather
# than a failed run. The description is cut to fit under the rendered
# sections; a Bead whose sections leave no room for it is held back so one
# unpublishable record cannot keep failing every batch it lands in.
linear_body_limit=250000
sync_state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/beads-linear-sync"
reconciliation_state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/beads-reconciliation"

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
  mapfile -d '' -t local_settings < <(
    # shellcheck source=/dev/null
    . "$env_file" >/dev/null
    printf '%s\0' "${BEADS_LINEAR_SYNC_REPOS:-}" "${LINEAR_API_KEY:-}" "${LINEAR_TEAM_ID:-}"
  )
  if [ "${#local_settings[@]}" -ne 3 ]; then
    log "Could not load local Linear settings"
    exit 1
  fi
  export BEADS_LINEAR_SYNC_REPOS="${local_settings[0]}"
  export LINEAR_API_KEY="${local_settings[1]}"
  export LINEAR_TEAM_ID="${local_settings[2]}"
  unset local_settings
fi

# Machine-local credentials must not override the managed database authority.
unset BEADS_DOLT_DATA_DIR BEADS_FEDERATION_HUB BEADS_DIR BEADS_DB
export BEADS_DOLT_SERVER_HOST="kyber.tail950b36.ts.net"
export BEADS_DOLT_SERVER_PORT="3307"
export BEADS_DOLT_SERVER_USER="beads"
export BEADS_DOLT_SERVER_MODE="1"
export BEADS_DOLT_AUTO_START="0"
export BEADS_NODE_ID="kyber"
export BEADS_ACTOR="beads-linear-reconciler"
export BD_EVENTS_JOURNAL="1"
export DOLT_CLI_USER="beads"
export DOLT_CLI_PASSWORD=""

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
reconciliation_lock_file="$reconciliation_state_dir/reconcile-$repo_slug.lock"
push_progress_file="$sync_state_dir/push-progress-$repo_slug"

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
  local operation="$1"
  local output
  local status
  local category
  local cause
  local diagnostic
  shift

  if output="$("$@" --json 2>/dev/null)"; then
    status=0
  else
    status=$?
  fi

  # bd may return zero after individual API operations were rejected. Treat
  # its circuit-breaker warning as a deferred run regardless of exit status.
  if [[ $output == *"rate limit circuit breaker"* ]]; then
    return 75
  fi

  # A successful process may still contain rejected issue operations. Require
  # one complete, clean result before recording any batch progress or cursor.
  # Capture payloads only in memory: error messages can contain private issue
  # text, repository identifiers, or credentials and must never reach logs.
  if [ "$status" -eq 0 ] && @jq@/bin/jq -e -s '
    length == 1 and (.[0] |
      type == "object" and
      .success == true and
      .stats.errors == 0 and
      (.warnings == null or (.warnings | type == "array" and length == 0)) and
      (.error == null or .error == ""))
  ' <<<"$output" >/dev/null 2>&1; then
    return 0
  fi

  # A pull whose only warnings are unresolved dependency relations is still a
  # complete pull of the issues themselves: the relation target is not linked
  # in Beads, and that never resolves on retry. Rejecting it would block every
  # later cycle behind those same edges. Only the count is logged.
  local unresolved_relations
  if [ "$operation" = pull ] && [ "$status" -eq 0 ] && unresolved_relations="$(@jq@/bin/jq -e -r -s '
    if length == 1 and (.[0] |
      type == "object" and
      .success == true and
      .stats.errors == 0 and
      (.error == null or .error == "") and
      (.warnings | type == "array" and length > 0 and
        all(type == "string" and test("^Failed to (build dependency resolver:|resolve dependency |create dependency )"))))
    then (.[0].warnings | length) else empty end
  ' <<<"$output" 2>/dev/null)"; then
    log "Linear pull completed with $unresolved_relations unresolved dependency relation warning(s)"
    return 0
  fi

  # A push whose only warnings are labels the tracker team does not define
  # still published every issue: bd drops those labels from the payload.
  # Local-only control labels never exist on the tracker, so rejecting the
  # result would fail every batch that carries one on every cycle. Only the
  # count is logged.
  local skipped_labels
  if [ "$operation" = push ] && [ "$status" -eq 0 ] && skipped_labels="$(@jq@/bin/jq -e -r -s '
    if length == 1 and (.[0] |
      type == "object" and
      .success == true and
      .stats.errors == 0 and
      (.error == null or .error == "") and
      (.warnings | type == "array" and length > 0 and
        all(type == "string" and test("^linear: bead \\S+: label \".*\" not found on Linear team \\(skipped\\)"))))
    then (.[0].warnings | length) else empty end
  ' <<<"$output" 2>/dev/null)"; then
    log "Linear push completed with $skipped_labels skipped label warning(s)"
    return 0
  fi

  # Only fixed categories leave this boundary, never source error strings.
  case "$output" in
  *"searching local issues"*) category="local-read" ;;
  *"building state cache"*) category="state-cache" ;;
  *"batch pushing issues"*) category="batch-push" ;;
  *"context deadline exceeded"* | *"context canceled"*) category="context-timeout" ;;
  *"lock wait timeout"* | *"deadlock"*) category="database-lock" ;;
  *) category="unclean-result" ;;
  esac
  case "${output,,}" in
  *"rate limit"* | *"too many requests"*) cause="rate-limit" ;;
  *"deadline exceeded"* | *"timeout"* | *"context canceled"*) cause="timeout" ;;
  *"connection"* | *"broken pipe"* | *"unexpected eof"* | *"no such host"*) cause="connection" ;;
  *"deadlock"* | *"lock wait"* | *"transaction conflict"*) cause="database-lock" ;;
  *"not found"* | *"not exist"*) cause="not-found" ;;
  *"unauthorized"* | *"forbidden"* | *"authentication"*) cause="authentication" ;;
  *) cause="unknown" ;;
  esac
  if [ "$status" -eq 124 ]; then
    category="command-timeout"
    cause="timeout"
  fi
  # Summarize the rejected contract without copying any payload values. The
  # warning prefixes identify native sync operations, not their private causes.
  if ! diagnostic="$(@jq@/bin/jq -r -s '
    def counter:
      if type == "number" and . >= 0 and . == floor then tostring else type end;
    def family:
      if type != "string" then "invalid"
      elif test("^Failed to (build dependency resolver:|resolve dependency |create dependency )") then "dependency"
      elif test("^linear: bead \\S+: label \".*\" not found on Linear team \\(skipped\\)") then "skipped-label"
      elif startswith("Failed to update last_sync:") then "cursor"
      elif startswith("Failed to update external_ref ") then "external-ref"
      elif startswith("Failed to record push hash ") then "push-hash"
      elif startswith("Failed to update ") then "update"
      elif startswith("Failed to create ") then "create"
      elif startswith("Failed to fetch ") then "fetch"
      elif test("^Failed to (prepare |generate ID )") then "prepare"
      elif startswith("Failed to push ") then "push"
      else "unknown" end;
    if length != 1 then "shape=result-count count=\(length)"
    elif (.[0] | type) != "object" then "shape=\(.[0] | type)"
    else .[0] |
      (if (.warnings | type) == "array" then .warnings else [] end) as $warnings |
      (if (.error | type) == "string" and .error != "" then [.error] else [] end) as $errors |
      "shape=object success=\(.success | if type == "boolean" then tostring else type end)" +
      " stats=\(.stats | type) errors=\((if (.stats | type) == "object" then .stats.errors else null end) | counter)" +
      " warnings=\(.warnings | if type == "array" then length else type end)" +
      " error=\(.error | if . == null or . == "" then "none" elif type == "string" then "present" else type end)" +
      " families=\([$warnings[], $errors[] | family] | unique | join(","))"
    end
  ' <<<"$output" 2>/dev/null)"; then
    diagnostic="shape=invalid-json"
  fi
  log "Linear result rejected: category=$category exit=$status cause=$cause operation=$operation $diagnostic"
  if [ "$status" -ne 0 ]; then
    return "$status"
  fi
  return 65
}

push_issue_batches() {
  local issue_ids="$1"
  local description="$2"
  # Optional newline-delimited "id closed_at" lines aligned one-to-one with
  # issue_ids. Each successfully pushed batch is appended to progress_file so
  # later runs skip those Beads instead of re-burning the API budget on them.
  local progress_entries="${3:-}"
  local progress_file="${4:-}"
  local batch_size=10
  local batch_count
  local batch_ids
  local batch_number
  local batch_start
  local status
  local rejected_status=0
  local rejected_batches=0
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

    if run_linear push @coreutils@/bin/timeout 120 "$bd_cli" -C "$repo_dir" linear sync --push --issues "$batch_ids" --no-wait; then
      if [ -n "$progress_file" ] && [ -n "$progress_entries" ]; then
        printf '%s\n' "$progress_entries" |
          @coreutils@/bin/tail -n +"$((batch_start + 1))" |
          @coreutils@/bin/head -n "$batch_size" >>"$progress_file"
      fi
    else
      status=$?
      if [ "$status" -eq 75 ]; then
        log "Linear push deferred; the next 900-second run will retry"
        return 75
      fi
      log "Linear push failed with status $status"
      # A rejected result is scoped to the Beads in that batch, so the
      # remaining batches still publish and record their progress. Transport
      # and timeout failures are not scoped that way and still stop the run.
      if [ "$status" -ne 65 ]; then
        return "$status"
      fi
      rejected_status="$status"
      rejected_batches=$((rejected_batches + 1))
    fi
  done

  if [ "$rejected_status" -ne 0 ]; then
    log "Linear push rejected $rejected_batches of $batch_count $description batches"
    return "$rejected_status"
  fi
}

# A push renders the acceptance criteria, design, and notes sections and a
# bd marker comment after the description in the Linear body, and the pull
# imports that rendered body back into the Bead description, so each cycle
# appends another copy of every section. The description is cut at the first
# rendered heading or marker before it is pushed; the fields stay the source
# of those sections.
# shellcheck disable=SC2016 # jq programs; $ names are jq variables.
rendered_sections_jq='
  def issues: if type == "object" and has("issues") then .issues else . end;
  def rendered_cut:
    (.description // "")
    | [match("(^|\\n\\n)## (Acceptance Criteria|Design|Notes)\\n\\n|\\n*<!-- bd-[a-z]+: [0-9a-z]+ -->"; "g")]
    | if length > 0 then .[0].offset else null end;
  def rendered_sections_length:
    ((.acceptance_criteria // "") | length) + ((.design // "") | length) + ((.notes // "") | length);
  def description_cap:
    [$body_limit - rendered_sections_length - 10000, 0] | max;
  def canonical_description:
    description_cap as $cap
    | (.description // "") as $description
    | $description[:(rendered_cut // ($description | length))]
    | sub("\\s+$"; "")
    | if $cap > 0 then .[:$cap] else . end;
  def fingerprint:
    {title, status, assignee, priority, issue_type, acceptance_criteria, design, notes, description: canonical_description}
    | tojson;
'
# shellcheck disable=SC2016 # jq program; $ names are jq variables.
rendered_section_cuts='
  ($ids | split(",") | map(select(length > 0) | {key: ., value: true}) | from_entries) as $wanted
  | issues | .[]
  | select($wanted[.id] != null and (rendered_cut != null or (description_cap > 0 and ((.description // "") | length) > description_cap)))
  | {id: .id, body: canonical_description}
'

written_since_snapshot() {
  "$bd_cli" -C "$repo_dir" history "$1" --events --limit 20 --json 2>/dev/null </dev/null |
    @jq@/bin/jq -r --arg since "$snapshot_taken_at" --arg actor "$BEADS_ACTOR" '
      if type == "array" then any(.[]; .actor != $actor and .created_at >= $since) else false end
    ' 2>/dev/null || echo false
}

# Beads whose description still carries rendered sections after a normalize
# pass; pushing them now would round-trip the sections or exceed the limit.
normalize_skipped_ids=""

normalize_rendered_sections() {
  local issues_json="$1"
  local issue_ids="$2"
  local description="$3"
  local cuts
  local cut
  local cut_id
  local normalized=0
  local skipped=0
  local description_file="$sync_state_dir/description-$repo_slug"

  normalize_skipped_ids=""
  if [ -z "$issue_ids" ]; then
    return 0
  fi
  cuts="$(@jq@/bin/jq -c --arg ids "$issue_ids" --argjson body_limit "$linear_body_limit" "$rendered_sections_jq $rendered_section_cuts" <<<"$issues_json")"
  if [ -z "$cuts" ]; then
    return 0
  fi
  while IFS= read -r cut; do
    cut_id="$(@jq@/bin/jq -r '.id' <<<"$cut")"
    if [ "$(written_since_snapshot "$cut_id")" = "true" ]; then
      skipped=$((skipped + 1))
      normalize_skipped_ids="${normalize_skipped_ids:+$normalize_skipped_ids,}$cut_id"
      continue
    fi
    @jq@/bin/jq -j '.body' <<<"$cut" >"$description_file"
    if "$bd_cli" -C "$repo_dir" update "$cut_id" --body-file "$description_file" --allow-empty-description >/dev/null 2>&1; then
      normalized=$((normalized + 1))
    else
      skipped=$((skipped + 1))
      normalize_skipped_ids="${normalize_skipped_ids:+$normalize_skipped_ids,}$cut_id"
    fi
  done <<<"$cuts"
  @coreutils@/bin/rm -f "$description_file"
  log "Normalized $normalized description(s) carrying rendered sections before the $description push; skipped $skipped"
}

# Filters "id ..." lines on stdin down to the Beads normalize did not skip.
drop_skipped_lines() {
  @gawk@/bin/awk -v skip="$normalize_skipped_ids" '
    BEGIN {
      count = split(skip, list, ",")
      for (i = 1; i <= count; i++) skipped[list[i]] = 1
    }
    NF && !($1 in skipped)
  '
}

run_dolt_sql() {
  local query="$1"

  "$dolt_cli" \
    --host="$BEADS_DOLT_SERVER_HOST" \
    --port="${BEADS_DOLT_SERVER_PORT:-3307}" \
    --user="${DOLT_CLI_USER:-beads}" \
    --no-tls \
    sql -q "$query" >/dev/null
}

query_dolt_json() {
  local query="$1"

  "$dolt_cli" \
    --host="$BEADS_DOLT_SERVER_HOST" \
    --port="${BEADS_DOLT_SERVER_PORT:-3307}" \
    --user="${DOLT_CLI_USER:-beads}" \
    --no-tls \
    sql -r json -q "$query"
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

# A cursor-free pull overwrites local assignment, workflow state, and labels.
# The pre-pull snapshot protects existing machine claims and orchestration
# labels. The durable journal then folds every non-reconciler mutation made
# during the pull over that snapshot in commit order, so a concurrent claim,
# release, completion, or label change wins. Each repair compares both fields
# it observed after the pull; a newer claim makes the guarded write refuse
# instead of transferring ownership from a live worker. Every caller runs this
# as a tested command, where errexit does not apply, so each step checks its
# own status.
repair_control_state_after_pull() {
  local linear_journal_file="$sync_state_dir/journal-$repo_slug.jsonl"
  local linear_current_file="$sync_state_dir/current-$repo_slug.json"
  local control_state_repairs
  local restored_control_state
  local restore_failures
  local repair
  local restore_id
  local restore_status
  local restore_assignee
  local pulled_status
  local pulled_assignee
  local restore_args
  local add_labels
  local remove_labels
  local label
  local wedged_records
  local wedged_id
  local claim_lane
  local reopened
  local restored_claims

  if ! all_issues="$("$bd_cli" -C "$repo_dir" list --all --json --limit 0)"; then
    log "Unable to list Beads after the Linear pull"
    return 1
  fi
  if ! "$bd_cli" -C "$repo_dir" events tail --since "$linear_journal_head" >"$linear_journal_file"; then
    log "Unable to read the Beads events journal after the Linear pull"
    return 1
  fi
  if ! printf '%s\n' "$all_issues" >"$linear_current_file" ||
    ! control_state_repairs="$(@jq@/bin/jq -c \
      --arg actor "$BEADS_ACTOR" \
      --slurpfile journal "$linear_journal_file" \
      --slurpfile current "$linear_current_file" \
      -f @linearControlStateJq@ <<<"$issues_before_pull")"; then
    log "Unable to fold the Beads events journal over the pre-pull snapshot"
    return 1
  fi
  @coreutils@/bin/rm -f "$linear_journal_file" "$linear_current_file"

  # Beads whose status or assignee a repair below changed back from what the
  # pull wrote. The tracker still holds the pulled state, so the pushed-active
  # ledger's record of what the tracker last received is stale for them.
  repaired_ids=""
  if [ -n "$control_state_repairs" ]; then
    log "Restoring locally authoritative control state after pull"
    restored_control_state=0
    restore_failures=0
    while IFS= read -r repair; do
      restore_id="$(@jq@/bin/jq -r '.id' <<<"$repair")"
      restore_status="$(@jq@/bin/jq -r '.desired_status' <<<"$repair")"
      restore_assignee="$(@jq@/bin/jq -r '.desired_assignee' <<<"$repair")"
      pulled_status="$(@jq@/bin/jq -r '.current_status' <<<"$repair")"
      pulled_assignee="$(@jq@/bin/jq -r '.current_assignee' <<<"$repair")"
      restore_args=()
      if [ "$restore_assignee" != "$pulled_assignee" ]; then
        restore_args+=(--assignee "$restore_assignee")
      fi
      if [ "$restore_status" != "$pulled_status" ]; then
        restore_args+=(--status "$restore_status")
      fi
      mapfile -t add_labels < <(@jq@/bin/jq -r '.add_labels[]' <<<"$repair")
      for label in "${add_labels[@]}"; do
        restore_args+=(--add-label "$label")
      done
      mapfile -t remove_labels < <(@jq@/bin/jq -r '.remove_labels[]' <<<"$repair")
      for label in "${remove_labels[@]}"; do
        restore_args+=(--remove-label "$label")
      done
      if [ "${#restore_args[@]}" -eq 0 ]; then
        continue
      fi
      # Label-only repairs need a no-op field update for the CAS guards to ride.
      if [ "$restore_status" = "$pulled_status" ] && [ "$restore_assignee" = "$pulled_assignee" ]; then
        restore_args+=(--status "$pulled_status")
      fi
      if "$bd_cli" -C "$repo_dir" update "$restore_id" "${restore_args[@]}" \
        --if-status="$pulled_status" --if-assignee="$pulled_assignee" >/dev/null 2>&1; then
        restored_control_state=$((restored_control_state + 1))
        if [ "$restore_status" != "$pulled_status" ] || [ "$restore_assignee" != "$pulled_assignee" ]; then
          repaired_ids="${repaired_ids:+$repaired_ids,}$restore_id"
        fi
      else
        restore_failures=$((restore_failures + 1))
      fi
    done <<<"$control_state_repairs"
    log "Restored $restored_control_state control state record(s); skipped $restore_failures superseded or refused repair(s)"
  fi

  # A lane claim made while the pull was in flight is not in the pre-pull
  # snapshot, so the pull leaves it in_progress and unassigned. The claim's
  # guarded update also appends a `lane-claim:<lane>` note marker, which the
  # pull never touches, so an unreleased marker names the lane to restore.
  # Records without a marker are the older invariant repair for malformed
  # records that predate journal coverage; those reopen. Both guarded updates
  # skip any Bead a worker has since re-claimed.
  if ! wedged_records="$(@jq@/bin/jq -r '
    def claim_lane:
      (.notes // "") as $notes
      | ($notes | rindex("lane-claim:")) as $claim
      | ($notes | rindex("lane-release:")) as $release
      | if $claim == null or ($release != null and $release > $claim) then ""
        else ($notes[$claim + 11:] | split("\n")[0] | split(" ")[0]) end
      | if test("^[a-z][a-z0-9_-]{0,31}$") then . else "" end;
    (if type == "object" and has("issues") then .issues else . end)
    | .[]
    | select(.status == "in_progress" and (.assignee // "") == "")
    | [.id, claim_lane]
    | @tsv
  ' <<<"$all_issues")"; then
    log "Unable to select unassigned in_progress Beads after the Linear pull"
    return 1
  fi
  if [ -n "$wedged_records" ]; then
    reopened=0
    restored_claims=0
    while IFS=$'\t' read -r wedged_id claim_lane; do
      if [ -n "$claim_lane" ]; then
        if "$bd_cli" -C "$repo_dir" update "$wedged_id" --if-status=in_progress --if-assignee= --assignee="$claim_lane" >/dev/null 2>&1; then
          restored_claims=$((restored_claims + 1))
          repaired_ids="${repaired_ids:+$repaired_ids,}$wedged_id"
        fi
      elif "$bd_cli" -C "$repo_dir" update "$wedged_id" --if-status=in_progress --if-assignee= --status=open >/dev/null 2>&1; then
        reopened=$((reopened + 1))
        repaired_ids="${repaired_ids:+$repaired_ids,}$wedged_id"
      fi
    done <<<"$wedged_records"
    if [ "$restored_claims" -gt 0 ]; then
      log "Restored $restored_claims lane claim(s) made while the pull was in flight"
    fi
    if [ "$reopened" -gt 0 ]; then
      log "Reopened $reopened unassigned in_progress Bead(s) the pull left behind"
    fi
  fi
}

# Once the cursor is cleared, the pull can leave local state overwritten
# however the run ends: success, a failed or timed-out pull, a stop signal, or
# an errexit abort. Each of those paths calls this, and it runs once. A failed
# pull or repair also puts the prior cursor back.
restore_after_pull() {
  local status=0

  if [ "$restore_state" != pending ]; then
    return 0
  fi
  restore_state=running
  repair_control_state_after_pull || status=$?
  if [ "$pull_status" != 0 ] || [ "$status" -ne 0 ]; then
    restore_linear_last_sync || status=1
  fi
  restore_state=complete
  if [ -n "$deferred_signal" ]; then
    trap - "$deferred_signal"
    kill -s "$deferred_signal" "$$"
  fi
  return "$status"
}

# Bash runs a trap only after the foreground command returns, so a stop during
# the pull lands here once the pull's process group is gone. One that lands
# while the restore runs waits for it. Re-raising keeps the signal as the exit
# cause for the service manager instead of a plain nonzero status.
on_restore_signal() {
  local signal="$1"

  if [ "$restore_state" = running ]; then
    deferred_signal="$signal"
    return 0
  fi
  restore_after_pull || true
  trap - "$signal"
  kill -s "$signal" "$$"
}

on_restore_exit() {
  local status=$?

  if ! restore_after_pull && [ "$status" -eq 0 ]; then
    exit 1
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
@coreutils@/bin/mkdir -p "$sync_state_dir" "$reconciliation_state_dir"
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
# The Linear workflow has no blocked state; a blocked Bead is unstarted work.
ensure_config linear.outbound_state_map.blocked Todo
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

  completion_issue="$("$bd_cli" -C "$repo_dir" show "$completion_bead_id" --json)"
  completion_status="$(@jq@/bin/jq -r '.[0].status // empty' <<<"$completion_issue")"
  completion_assignee="$(@jq@/bin/jq -r '.[0].assignee // empty' <<<"$completion_issue")"
  completion_ref="$(@jq@/bin/jq -r '.[0].external_ref // empty' <<<"$completion_issue")"
  if [ -z "$completion_status" ]; then
    log "Completion Bead was not found"
    exit 66
  fi

  completion_reference_pending=0
  if [[ ! $completion_ref =~ /issue/([A-Z][A-Z0-9]*-[0-9]+)(/|$) ]]; then
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

  # Commit the terminal Bead on the authority before any Linear request. If the API
  # is unavailable, the periodic closed-first pass can retry without an
  # inbound pull ever reviving the issue.
  "$bd_cli" -C "$repo_dir" dolt commit -m "chore(beads): record accepted completion" >/dev/null 2>&1

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
  if [[ ! $completion_ref =~ /issue/([A-Z][A-Z0-9]*-[0-9]+)(/|$) ]]; then
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

# Kyber owns both the live Beads database and this Linear reconciliation.
# SQL mutations are shared immediately; there is no database push/pull phase.

linear_status="$("$bd_cli" -C "$repo_dir" linear status --json)"
linear_database="$(@jq@/bin/jq -r '.dolt_database // empty' "$repo_dir/.beads/metadata.json")"
if [[ ! $linear_database =~ ^[A-Za-z0-9_]+$ ]]; then
  log "Beads metadata does not contain a valid Dolt database name"
  exit 1
fi
if [ -s "$sync_checkpoint_file" ]; then
  previous_sync="$(<"$sync_checkpoint_file")"
else
  previous_sync="$(@jq@/bin/jq -r '.last_sync // ""' <<<"$linear_status")"
fi

# Terminal Beads are authoritative after acceptance. Publish them before the
# full inbound refresh so a stale active Linear record can never win during
# the timer-latency window. On an initial run, publish every linked terminal
# record once; later runs use the successful-cycle checkpoint. The ledger of
# pushed "id closed_at" pairs persists across cycles and is keyed by closed_at
# because every push (and pull) bumps updated_at past the cycle start: keying
# by updated_at re-selects the whole terminal set every run until the rate
# limit defers it, so the checkpoint never advances. A pending completion
# marker bypasses the ledger so its recovery push always happens. Capture the
# ordered mutation cursor before the snapshot: events that race the listing
# may appear in both inputs, but replaying their full state is idempotent.
linear_journal_head="$(query_dolt_json "USE \`$linear_database\`; SELECT COALESCE(MAX(next_seq), 0) AS head FROM bd_events_seq;" | @jq@/bin/jq -er '.rows[0].head // "0"')"
if [[ ! $linear_journal_head =~ ^[0-9]+$ ]]; then
  log "Beads events journal returned an invalid sequence"
  exit 1
fi
snapshot_taken_at="$(@coreutils@/bin/date -u '+%Y-%m-%dT%H:%M:%SZ')"
issues_before_pull="$("$bd_cli" -C "$repo_dir" list --all --json --limit 0)"
pushed_progress_input=/dev/null
if [ -s "$push_progress_file" ]; then
  pushed_progress_input="$push_progress_file"
fi
# Keep deferred progress content out of jq's argv. The file may contain many
# batches, so passing it with --arg exceeds Linux's per-argument limit.
closed_push_selection="$(@jq@/bin/jq -r --arg previous_sync "$previous_sync" --argjson body_limit "$linear_body_limit" --rawfile pushed "$pushed_progress_input" "$rendered_sections_jq"'
  def body_length: (canonical_description | length) + rendered_sections_length;
  issues
  | ($pushed | split("\n") | map(select(length > 0) | {key: ., value: true}) | from_entries) as $already_pushed
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
    | {
      entry: "\(.id) \(.closed_at // "")",
      oversized: (body_length > $body_limit),
      pending: (
        (.metadata.linear_completion_pending // false) == true
        or (.metadata.linear_completion_pending // false) == "true"
      ),
    }
    | select(.pending or (.entry as $entry | ($already_pushed | has($entry)) | not))
  ]
  | {
    entries: (map(select(.oversized | not) | .entry) | join("\n")),
    oversized: (map(select(.oversized)) | length),
  }
  | "\(.oversized)\n\(.entries)"
' <<<"$issues_before_pull")"
oversized_push_count="$(@coreutils@/bin/head -n 1 <<<"$closed_push_selection")"
closed_push_entries="$(@coreutils@/bin/tail -n +2 <<<"$closed_push_selection")"
if [ "$oversized_push_count" -gt 0 ]; then
  log "Holding back $oversized_push_count terminal Bead(s) whose body exceeds the Linear issue limit"
fi
closed_ids="$(printf '%s\n' "$closed_push_entries" | @gawk@/bin/awk 'NF { print $1 }' | @coreutils@/bin/paste -sd, -)"
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

normalize_rendered_sections "$issues_before_pull" "$closed_ids" "terminal"
if [ -n "$normalize_skipped_ids" ]; then
  closed_push_entries="$(printf '%s\n' "$closed_push_entries" | drop_skipped_lines)"
  closed_ids="$(printf '%s\n' "$closed_push_entries" | @gawk@/bin/awk 'NF { print $1 }' | @coreutils@/bin/paste -sd, -)"
fi
if push_issue_batches "$closed_ids" "terminal" "$closed_push_entries" "$push_progress_file"; then
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
    if [[ $pending_completion_ref =~ /issue/([A-Z][A-Z0-9]*-[0-9]+)(/|$) ]]; then
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
linear_last_sync_before_pull="$(@jq@/bin/jq -r '.last_sync // ""' <<<"$linear_status")"
pull_status=""
deferred_signal=""
restore_state=pending
trap on_restore_exit EXIT
trap 'on_restore_signal TERM' TERM
trap 'on_restore_signal INT' INT
trap 'on_restore_signal HUP' HUP
run_dolt_sql "USE \`$linear_database\`; DELETE FROM local_metadata WHERE \`key\` = 'linear.last_sync';"

# Pull open and closed Linear work so cancels/Done land in Beads. A rate-limit
# failure is deferred to the next scheduled run instead of making launchd
# hot-loop a failed job.
log "Pulling complete Linear state"
if run_linear pull @coreutils@/bin/timeout 720 "$bd_cli" -C "$repo_dir" linear sync \
  --pull \
  --state all \
  --relations \
  --no-wait; then
  pull_status=0
else
  pull_status=$?
fi

repair_status=0
restore_after_pull || repair_status=$?
if [ "$pull_status" -ne 0 ]; then
  if [ "$pull_status" -eq 75 ]; then
    log "Linear pull deferred; the next 900-second run will retry"
    exit "$repair_status"
  fi
  log "Linear pull failed with status $pull_status"
  exit "$pull_status"
fi
if [ "$repair_status" -ne 0 ]; then
  exit "$repair_status"
fi

# Select the active push from the repaired state. The post-pull listing still
# shows a restored claim as the tracker's close, so it would never be pushed
# and the next pull would close it again.
all_issues="$("$bd_cli" -C "$repo_dir" list --all --json --limit 0)"
# The push and the pull both bump updated_at, so by timestamp alone a Bead
# pushed last cycle is re-selected every cycle. The ledger keeps a hash of
# the content each push sent (title, state, fields, and the cut description);
# a linked Bead whose hash is unchanged has nothing new to push. Unlinked
# Beads always retry.
pushed_active_file="$sync_state_dir/pushed-active-$repo_slug"
if [ -n "$repaired_ids" ] && [ -s "$pushed_active_file" ]; then
  @gawk@/bin/awk -v repaired="$repaired_ids" '
    BEGIN {
      count = split(repaired, list, ",")
      for (i = 1; i <= count; i++) dropped[list[i]] = 1
    }
    !($1 in dropped)
  ' "$pushed_active_file" >"$pushed_active_file.tmp"
  @coreutils@/bin/mv -f "$pushed_active_file.tmp" "$pushed_active_file"
fi
pushed_active_input=/dev/null
if [ -s "$pushed_active_file" ]; then
  pushed_active_input="$pushed_active_file"
fi
changed_active_candidates="$(@jq@/bin/jq -r --arg previous_sync "$previous_sync" --argjson body_limit "$linear_body_limit" "$rendered_sections_jq"'
  def body_length: (canonical_description | length) + rendered_sections_length;
  issues | .[]
  # Deferred has no outbound state mapping, so bd rejects every batch that
  # carries one.
  | select(.status != "closed" and .status != "deferred")
  | ((.external_ref // "") | contains("linear.app") | not) as $unlinked
  | select($previous_sync == "" or .updated_at >= $previous_sync or $unlinked)
  | "\(.id) \(if body_length > $body_limit then "oversized" else "sized" end) \(if $unlinked then "unlinked" else "linked" end) \(fingerprint)"
' <<<"$all_issues")"
oversized_active_count=0
changed_active_ids=""
pushed_active_next="$pushed_active_file.next"
: >"$pushed_active_next"
while read -r candidate_id candidate_size candidate_link candidate_fingerprint; do
  if [ -z "$candidate_id" ]; then
    continue
  fi
  if [ "$candidate_size" = oversized ]; then
    oversized_active_count=$((oversized_active_count + 1))
    continue
  fi
  candidate_hash="$(printf '%s' "$candidate_fingerprint" | @coreutils@/bin/sha256sum)"
  candidate_hash="${candidate_hash%% *}"
  if [ "$candidate_link" = linked ] && @gawk@/bin/awk -v id="$candidate_id" -v hash="$candidate_hash" '$1 == id && $2 == hash { found = 1 } END { exit !found }' "$pushed_active_input"; then
    continue
  fi
  changed_active_ids="${changed_active_ids:+$changed_active_ids,}$candidate_id"
  printf '%s %s\n' "$candidate_id" "$candidate_hash" >>"$pushed_active_next"
done <<<"$changed_active_candidates"
if [ "$oversized_active_count" -gt 0 ]; then
  log "Holding back $oversized_active_count active Bead(s) whose body exceeds the Linear issue limit"
fi

# Push only the active local delta after inbound reconciliation. Terminal
# issues never enter this phase because they were made durable before pull.
normalize_rendered_sections "$all_issues" "$changed_active_ids" "changed active"
if [ -n "$normalize_skipped_ids" ]; then
  drop_skipped_lines <"$pushed_active_next" >"$pushed_active_next.tmp"
  @coreutils@/bin/mv -f "$pushed_active_next.tmp" "$pushed_active_next"
  changed_active_ids="$(@gawk@/bin/awk 'NF { print $1 }' "$pushed_active_next" | @coreutils@/bin/paste -sd, -)"
fi
# A rejection is scoped to the Beads in its own batch, so the ledger has to
# keep the batches that did publish. Discarding it whenever any batch fails
# re-pushes every changed Bead next cycle, which holds the shared Dolt write
# transaction open for the whole run and fails unrelated claims with a
# serialization conflict.
pushed_active_progress="$pushed_active_file.progress"
: >"$pushed_active_progress"
push_status=0
push_issue_batches "$changed_active_ids" "changed active" \
  "$(@coreutils@/bin/cat "$pushed_active_next")" "$pushed_active_progress" || push_status=$?
if [ -s "$pushed_active_progress" ]; then
  {
    @gawk@/bin/awk 'NR == FNR { pushed[$1] = 1; next } !($1 in pushed)' "$pushed_active_progress" "$pushed_active_input"
    @coreutils@/bin/cat "$pushed_active_progress"
  } >"$pushed_active_file.tmp"
  @coreutils@/bin/mv -f "$pushed_active_file.tmp" "$pushed_active_file"
fi
@coreutils@/bin/rm -f "$pushed_active_progress"
if [ "$push_status" -ne 0 ]; then
  if [ "$push_status" -eq 75 ]; then
    exit 0
  fi
  exit "$push_status"
fi

"$bd_cli" -C "$repo_dir" dolt commit -m "chore(beads): sync Linear" >/dev/null 2>&1

printf '%s\n' "$cycle_started" >"$sync_checkpoint_file.tmp"
@coreutils@/bin/mv -f "$sync_checkpoint_file.tmp" "$sync_checkpoint_file"

"$bd_cli" -C "$repo_dir" linear status --json
