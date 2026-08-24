#!/usr/bin/env bash

set -euo pipefail

bd_cli="@bd@"
linear_cli="@linear@"
default_repo_dir="@repoDir@"
repo_dir="$default_repo_dir"
linear_workspace="@linearWorkspace@"
linear_team_id="@linearTeamId@"
linear_credentials_file="${XDG_CONFIG_HOME:-$HOME/.config}/linear/credentials.toml"
sync_state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/beads-linear-sync"
sync_checkpoint_file="$sync_state_dir/last-success"

log() {
  printf '[beads-linear-sync] %s\n' "$*"
}

ensure_config() {
  local key="$1"
  local expected="$2"
  local actual

  actual="$("$bd_cli" -C "$repo_dir" config get "$key" 2>/dev/null || true)"
  if [ "$actual" != "$expected" ]; then
    "$bd_cli" -C "$repo_dir" config set "$key" "$expected"
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

  if [ -n "$output" ]; then
    printf '%s\n' "$output"
  fi

  # bd may return zero after individual API operations were rejected. Treat
  # its circuit-breaker warning as a deferred run regardless of exit status.
  if [[ $output == *"rate limit circuit breaker"* ]]; then
    return 75
  fi

  return "$status"
}

# Prefer the machine-local dotfiles .env (same convention as other launchd
# services) before the Linear CLI credential file or keyring. Keep already
# exported Linear/Beads values ahead of the file.
preset_api_key="${LINEAR_API_KEY:-}"
preset_repo_dir="${BEADS_LINEAR_SYNC_REPO:-}"
env_file="${DOTFILES_ENV_FILE:-$HOME/dotfiles/.env}"
if [ -f "$env_file" ]; then
  set -a
  # shellcheck source=/dev/null
  . "$env_file"
  set +a
fi
if [ -n "$preset_api_key" ]; then
  LINEAR_API_KEY="$preset_api_key"
fi
if [ -n "$preset_repo_dir" ]; then
  BEADS_LINEAR_SYNC_REPO="$preset_repo_dir"
fi

repo_dir="${BEADS_LINEAR_SYNC_REPO:-$default_repo_dir}"
if [ ! -d "$repo_dir/.beads" ]; then
  log "Not a Beads repo: $repo_dir"
  exit 1
fi
if [ "$repo_dir" != "$default_repo_dir" ]; then
  repo_slug="${repo_dir##*/}"
  sync_checkpoint_file="$sync_state_dir/last-success-$repo_slug"
fi

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
"$bd_cli" -C "$repo_dir" dolt commit -m "chore(beads): configure Linear sync"

# Pull the Dolt remote first so Linear conflict resolution sees the newest
# Beads timestamps from every machine.
"$bd_cli" -C "$repo_dir" sync --yes

if [ -s "$sync_checkpoint_file" ]; then
  previous_sync="$(<"$sync_checkpoint_file")"
else
  previous_sync="$(@jq@/bin/jq -r '.last_sync // ""' <<<"$("$bd_cli" -C "$repo_dir" linear status --json)")"
fi

# Pull open and closed Linear work so cancels/Done land in Beads. Let Beads'
# staleness guard debounce calls made at the five-minute timer boundary. A
# rate-limit failure is deferred to the next scheduled run instead of making
# launchd hot-loop a failed job.
log "Pulling Linear work if stale"
if run_linear "$bd_cli" -C "$repo_dir" linear sync \
  --pull-if-stale \
  --threshold 5m \
  --state all \
  --relations \
  --no-wait; then
  :
else
  status=$?
  if [ "$status" -eq 75 ]; then
    log "Linear pull deferred; the next 300-second run will retry"
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

# Push only the active local delta since the previous successful pull. The
# first successful run seeds all active work; steady-state runs remain small.
if [ -n "$changed_ids" ]; then
  log "Pushing changed active Beads"
  if run_linear "$bd_cli" -C "$repo_dir" linear sync --push --issues "$changed_ids" --no-wait; then
    :
  else
    status=$?
    if [ "$status" -eq 75 ]; then
      log "Linear push deferred; the next 300-second run will retry"
      exit 0
    fi
    log "Linear push failed with status $status"
    exit "$status"
  fi
else
  log "No changed active Beads to push"
fi

"$bd_cli" -C "$repo_dir" dolt commit -m "chore(beads): sync Linear"
"$bd_cli" -C "$repo_dir" sync --yes

printf '%s\n' "$cycle_started" >"$sync_checkpoint_file.tmp"
@coreutils@/bin/mv -f "$sync_checkpoint_file.tmp" "$sync_checkpoint_file"

"$bd_cli" -C "$repo_dir" linear status --json
