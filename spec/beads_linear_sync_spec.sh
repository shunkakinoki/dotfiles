#!/usr/bin/env bash
# shellcheck disable=SC2016,SC2329

Describe 'Beads Linear synchronization'
SCRIPT="$PWD/home-manager/services/dolt/linear-sync.sh"
MODULE="$PWD/home-manager/services/dolt/default.nix"

Describe 'script properties'
It 'uses strict bash mode'
When run bash -c "grep -F 'set -euo pipefail' '$SCRIPT' >/dev/null"
The status should be success
End

It 'passes bash syntax validation after placeholder replacement'
When run bash -c "sed 's|@[A-Za-z_][A-Za-z0-9_]*@|/usr|g' '$SCRIPT' | bash -n"
The status should be success
End

It 'does not persist the Linear API key in Beads config'
When run grep -F 'config set linear.api' "$SCRIPT"
The status should be failure
End

It 'bounds workspace keyring lookup without forwarding an empty Linear key'
When run bash -c "grep -F '@coreutils@/bin/env -u LINEAR_API_KEY' '$SCRIPT' >/dev/null"
The status should be success
End

It 'reads and protects the Linear CLI credential file for background use'
When run bash -c "grep -F '@coreutils@/bin/chmod 600 \"\$linear_credentials_file\"' '$SCRIPT' >/dev/null && grep -F '@gawk@/bin/awk' '$SCRIPT' >/dev/null"
The status should be success
End

It 'loads Linear credentials from the local dotfiles .env when unset'
When run bash -c "grep -F 'DOTFILES_ENV_FILE:-\$HOME/dotfiles/.env' '$SCRIPT' >/dev/null"
The status should be success
End

It 'invokes jq through the Nix package binary path'
When run bash -c "grep -F '@jq@/bin/jq' '$SCRIPT' >/dev/null"
The status should be success
End

It 'supports the current Beads list envelope'
When run bash -c "grep -F 'if type == \"object\" and has(\"issues\") then .issues else . end' '$SCRIPT' >/dev/null"
The status should be success
End
End

Describe 'sync scope'
It 'pulls all Linear states when stale'
When run bash -c "grep -F -- '--pull-if-stale' '$SCRIPT' >/dev/null && grep -F -- '--threshold 5m' '$SCRIPT' >/dev/null && grep -F -- '--state all' '$SCRIPT' >/dev/null"
The status should be success
End

It 'pushes only changed active Beads'
When run bash -c "grep -F '.updated_at >= \$previous_sync' '$SCRIPT' >/dev/null && grep -F 'linear sync --push --issues \"\$changed_ids\" --no-wait' '$SCRIPT' >/dev/null"
The status should be success
End

It 'defers rate-limited work to the next timer run'
When run bash -c "test \"\$(grep -c 'next 300-second run will retry' '$SCRIPT')\" -eq 2 && grep -F 'rate limit circuit breaker' '$SCRIPT' >/dev/null"
The status should be success
End

It 'propagates non-rate-limit pull and push failures'
When run bash -c "test \"\$(grep -c 'failed with status \$status' '$SCRIPT')\" -eq 2 && test \"\$(grep -c 'exit \"\$status\"' '$SCRIPT')\" -eq 2"
The status should be success
End

It 'checkpoints a successful cycle for delta selection'
When run bash -c "checkpoint=\$(grep -n '\"\$cycle_started\" >\"\$sync_checkpoint_file.tmp\"' '$SCRIPT' | cut -d: -f1); final_sync=\$(grep -n 'sync --yes' '$SCRIPT' | tail -1 | cut -d: -f1); test \"\$checkpoint\" -gt \"\$final_sync\""
The status should be success
End

It 'federates Beads before and after Linear reconciliation'
When run bash -c "test \"\$(grep -c 'sync --yes' '$SCRIPT')\" -eq 2"
The status should be success
End

It 'commits internal Linear config before the first federation pull'
When run bash -c "config_commit=\$(grep -n 'configure Linear sync' '$SCRIPT' | cut -d: -f1); first_pull=\$(grep -n 'sync --yes' '$SCRIPT' | head -1 | cut -d: -f1); test \"\$config_commit\" -lt \"\$first_pull\""
The status should be success
End
End

Describe 'reconciliation behavior'
setup_reconciliation() {
  TEST_ROOT=$(mktemp -d)
  FAKE_BD="$TEST_ROOT/bd"
  RENDERED_SCRIPT="$TEST_ROOT/linear-sync.sh"
  COMMAND_LOG="$TEST_ROOT/commands.log"
  SYNC_COUNT="$TEST_ROOT/sync-count"
  STATE_HOME="$TEST_ROOT/state"
  COREUTILS="$TEST_ROOT/coreutils"
  jq_prefix=$(dirname "$(dirname "$(command -v jq)")")
  mkdir -p "$COREUTILS/bin"
  for command in chmod date env mkdir mv sleep timeout; do
    ln -s "$(command -v "$command")" "$COREUTILS/bin/$command"
  done

  cat >"$FAKE_BD" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$COMMAND_LOG"
if [ "${1:-}" = "-C" ]; then
  shift 2
fi
case "${1:-} ${2:-}" in
  "ping ")
    exit 0
    ;;
  "config get")
    exit 0
    ;;
  "config set" | "dolt commit")
    exit 0
    ;;
  "sync --yes")
    count=0
    if [ -s "$SYNC_COUNT" ]; then
      count=$(<"$SYNC_COUNT")
    fi
    count=$((count + 1))
    printf '%s\n' "$count" >"$SYNC_COUNT"
    if [ "${FAKE_LINEAR_MODE:-}" = "final-failure" ] && [ "$count" -eq 2 ]; then
      exit 42
    fi
    ;;
  "linear status")
    printf '%s\n' '{"last_sync":""}'
    ;;
  "linear sync")
    case "${FAKE_LINEAR_MODE:-success}" in
      rate-limit)
        printf '%s\n' 'rate limit circuit breaker is open'
        ;;
      hard-failure)
        exit 23
        ;;
      push-failure)
        if [[ " $* " == *" --push "* ]]; then
          exit 24
        fi
        ;;
    esac
    ;;
  "list --all")
    if [ -n "${FAKE_LIST_JSON:-}" ]; then
      printf '%s\n' "$FAKE_LIST_JSON"
    else
      printf '%s\n' '[{"id":"df-test","status":"open","updated_at":"2099-01-01T00:00:00Z"}]'
    fi
    ;;
esac
EOF
  chmod +x "$FAKE_BD"
  sed \
    -e "s|@bd@|$FAKE_BD|g" \
    -e 's|@linear@|/usr/bin/false|g' \
    -e "s|@repoDir@|$TEST_ROOT|g" \
    -e 's|@linearWorkspace@|test-workspace|g' \
    -e 's|@linearTeamId@|test-team|g' \
    -e "s|@coreutils@|$COREUTILS|g" \
    -e 's|@gawk@|/usr|g' \
    -e "s|@jq@|$jq_prefix|g" \
    "$SCRIPT" >"$RENDERED_SCRIPT"
}

cleanup_reconciliation() {
  rm -rf "$TEST_ROOT"
}

Before 'setup_reconciliation'
After 'cleanup_reconciliation'

It 'runs both federations around pull and delta push before checkpointing'
When run env COMMAND_LOG="$COMMAND_LOG" SYNC_COUNT="$SYNC_COUNT" XDG_STATE_HOME="$STATE_HOME" HOME="$TEST_ROOT" LINEAR_API_KEY=test bash "$RENDERED_SCRIPT"
The status should be success
The output should include 'Pushing changed active Beads'
The file "$STATE_HOME/beads-linear-sync/last-success" should be exist
The contents of file "$COMMAND_LOG" should include 'linear sync --pull-if-stale --threshold 5m --state all --relations --no-wait'
The contents of file "$COMMAND_LOG" should include 'linear sync --push --issues df-test --no-wait'
End

It 'defers a Linear rate limit without advancing the checkpoint'
When run env COMMAND_LOG="$COMMAND_LOG" SYNC_COUNT="$SYNC_COUNT" FAKE_LINEAR_MODE=rate-limit XDG_STATE_HOME="$STATE_HOME" HOME="$TEST_ROOT" LINEAR_API_KEY=test bash "$RENDERED_SCRIPT"
The status should be success
The output should include 'next 300-second run will retry'
The file "$STATE_HOME/beads-linear-sync/last-success" should not be exist
End

It 'propagates an ordinary Linear failure without advancing the checkpoint'
When run env COMMAND_LOG="$COMMAND_LOG" SYNC_COUNT="$SYNC_COUNT" FAKE_LINEAR_MODE=hard-failure XDG_STATE_HOME="$STATE_HOME" HOME="$TEST_ROOT" LINEAR_API_KEY=test bash "$RENDERED_SCRIPT"
The status should equal 23
The output should include 'Linear pull failed with status 23'
The file "$STATE_HOME/beads-linear-sync/last-success" should not be exist
End

It 'propagates a Linear push failure without advancing the checkpoint'
When run env COMMAND_LOG="$COMMAND_LOG" SYNC_COUNT="$SYNC_COUNT" FAKE_LINEAR_MODE=push-failure XDG_STATE_HOME="$STATE_HOME" HOME="$TEST_ROOT" LINEAR_API_KEY=test bash "$RENDERED_SCRIPT"
The status should equal 24
The output should include 'Linear push failed with status 24'
The file "$STATE_HOME/beads-linear-sync/last-success" should not be exist
End

It 'pushes a locally closed linked issue from a steady-state delta'
mkdir -p "$STATE_HOME/beads-linear-sync"
printf '%s\n' '2026-01-01T00:00:00Z' >"$STATE_HOME/beads-linear-sync/last-success"
When run env COMMAND_LOG="$COMMAND_LOG" SYNC_COUNT="$SYNC_COUNT" FAKE_LIST_JSON='[{"id":"df-closed","status":"closed","updated_at":"2099-01-01T00:00:00Z","external_ref":"https://linear.app/test/issue/TEST-1/closed"}]' XDG_STATE_HOME="$STATE_HOME" HOME="$TEST_ROOT" LINEAR_API_KEY=test bash "$RENDERED_SCRIPT"
The status should be success
The output should include 'Pushing changed active Beads'
The contents of file "$COMMAND_LOG" should include 'linear sync --push --issues df-closed --no-wait'
End

It 'does not checkpoint when final federation fails'
When run env COMMAND_LOG="$COMMAND_LOG" SYNC_COUNT="$SYNC_COUNT" FAKE_LINEAR_MODE=final-failure XDG_STATE_HOME="$STATE_HOME" HOME="$TEST_ROOT" LINEAR_API_KEY=test bash "$RENDERED_SCRIPT"
The status should equal 42
The output should include 'Pushing changed active Beads'
The file "$STATE_HOME/beads-linear-sync/last-success" should not be exist
End
End

Describe 'Home Manager service ownership'
It 'runs every five minutes on launchd'
When run bash -c "grep -F 'linearSyncIntervalSeconds = 300;' '$MODULE' >/dev/null && grep -F 'ThrottleInterval = linearSyncIntervalSeconds;' '$MODULE' >/dev/null && grep -F 'PATH = linearSyncPath;' '$MODULE' >/dev/null"
The status should be success
End

It 'installs the macOS launchd agent'
When run bash -c "grep -F 'launchd.agents.dolt-linear-sync' '$MODULE' >/dev/null"
The status should be success
End

It 'installs the Linux systemd timer'
When run bash -c "grep -F 'systemd.user.timers.dolt-linear-sync' '$MODULE' >/dev/null && grep -F 'OnCalendar = \"*-*-* *:00/5:00\";' '$MODULE' >/dev/null && grep -F 'X-SwitchMethod = \"restart\";' '$MODULE' >/dev/null"
The status should be success
End
End
End
