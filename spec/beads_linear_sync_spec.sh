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

It 'requires a comma-separated org/repo list from the local dotenv file'
When run bash -c "grep -F 'configured_repos=\"\${BEADS_LINEAR_SYNC_REPOS:-}\"' '$SCRIPT' >/dev/null && grep -F \"IFS=',' read -r -a repo_names\" '$SCRIPT' >/dev/null"
The status should be success
End

It 'dispatches each repository through an isolated child run'
When run bash -c "grep -F 'BEADS_LINEAR_SYNC_REPO_DIR=\"\$repo_path\" BEADS_LINEAR_SYNC_REPO_NAME=\"\$configured_repo\" BEADS_LINEAR_SYNC_REPO_CONTEXT=\"\$repo_context\" \"\$BASH\" \"\$0\" --repo' '$SCRIPT' >/dev/null"
The status should be success
End

It 'does not print configured repository identifiers or command output'
When run bash -c "grep -F 'context=\"[\$repo_context] \"' '$SCRIPT' >/dev/null && ! grep -F 'context=\"[\$repo_name] \"' '$SCRIPT' >/dev/null && ! grep -F 'printf '\''%s\\n'\'' \"\$output\"' '$SCRIPT' >/dev/null"
The status should be success
End

It 'does not retain a Nix-substituted repository fallback'
When run grep -F '@repoDir@' "$SCRIPT"
The status should be failure
End

It 'uses an org/repo-specific checkpoint'
When run bash -c "grep -F 'last-success-\$repo_slug' '$SCRIPT' >/dev/null"
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
It 'pulls all Linear states with the bounded full-refresh workaround'
When run bash -c "grep -F 'DELETE FROM local_metadata' '$SCRIPT' >/dev/null && grep -F -- '--pull' '$SCRIPT' >/dev/null && grep -F -- '--state all' '$SCRIPT' >/dev/null && ! grep -F -- '--pull-if-stale' '$SCRIPT' >/dev/null"
The status should be success
End

It 'pushes only changed active Beads'
When run bash -c "grep -F '.updated_at >= \$previous_sync' '$SCRIPT' >/dev/null && grep -F 'linear sync --push --issues \"\$batch_ids\" --no-wait' '$SCRIPT' >/dev/null"
The status should be success
End

It 'defers rate-limited work to the next timer run'
When run bash -c "test \"\$(grep -c 'next 900-second run will retry' '$SCRIPT')\" -eq 2 && grep -F 'rate limit circuit breaker' '$SCRIPT' >/dev/null"
The status should be success
End

It 'fails closed after ordinary pull, push, or federation failures'
When run bash -c "! grep -F 'continuing with outbound Beads reconciliation' '$SCRIPT' >/dev/null && ! grep -F 'continuing with local Beads state' '$SCRIPT' >/dev/null && grep -F 'log \"Linear pull failed with status \$status\"' '$SCRIPT' >/dev/null && grep -F 'log \"Linear push failed with status \$status\"' '$SCRIPT' >/dev/null"
The status should be success
End

It 'gives federation fsck a bounded budget below the outer deadline'
When run bash -c "grep -F 'federation_timeout_seconds=360' '$SCRIPT' >/dev/null && grep -F 'federation_fsck_timeout=300s' '$SCRIPT' >/dev/null && grep -F '@coreutils@/bin/timeout \"\$federation_timeout_seconds\"' '$SCRIPT' >/dev/null && grep -F '@coreutils@/bin/env BEADS_FSCK_TIMEOUT=\"\$federation_fsck_timeout\"' '$SCRIPT' >/dev/null"
The status should be success
End

It 'bounds inbound pull and small outbound batches'
When run bash -c "grep -F 'run_linear @coreutils@/bin/timeout 720 \"\$bd_cli\"' '$SCRIPT' >/dev/null && grep -F 'push_batch_size=10' '$SCRIPT' >/dev/null && grep -F 'run_linear @coreutils@/bin/timeout 120 \"\$bd_cli\"' '$SCRIPT' >/dev/null"
The status should be success
End

It 'checkpoints a successful cycle for delta selection'
When run bash -c "checkpoint=\$(grep -n '\"\$cycle_started\" >\"\$sync_checkpoint_file.tmp\"' '$SCRIPT' | cut -d: -f1); final_sync=\$(grep -n 'federate_beads \"post-sync\"' '$SCRIPT' | cut -d: -f1); test \"\$checkpoint\" -gt \"\$final_sync\""
The status should be success
End

It 'federates Beads before and after Linear reconciliation'
When run bash -c "test \"\$(grep -c '^federate_beads \"' '$SCRIPT')\" -eq 2 && grep -F 'federate_beads \"pre-sync\"' '$SCRIPT' >/dev/null && grep -F 'federate_beads \"post-sync\"' '$SCRIPT' >/dev/null"
The status should be success
End

It 'commits internal Linear config before the first federation pull'
When run bash -c "config_commit=\$(grep -n 'configure Linear sync' '$SCRIPT' | cut -d: -f1); first_pull=\$(grep -n 'federate_beads \"pre-sync\"' '$SCRIPT' | cut -d: -f1); test \"\$config_commit\" -lt \"\$first_pull\""
The status should be success
End
End

Describe 'reconciliation behavior'
setup_reconciliation() {
  TEST_ROOT=$(mktemp -d)
  FAKE_BD="$TEST_ROOT/bd"
  FAKE_DOLT_ROOT="$TEST_ROOT/dolt"
  RENDERED_SCRIPT="$TEST_ROOT/linear-sync.sh"
  COMMAND_LOG="$TEST_ROOT/commands.log"
  FSCK_TIMEOUT_LOG="$TEST_ROOT/fsck-timeouts.log"
  DOLT_LOG="$TEST_ROOT/dolt-commands.log"
  SYNC_COUNT="$TEST_ROOT/sync-count"
  STATE_HOME="$TEST_ROOT/state"
  ENV_FILE="$TEST_ROOT/dotenv"
  COREUTILS="$TEST_ROOT/coreutils"
  TEST_REPO_ID="test/repo-one"
  TEST_REPO="$TEST_ROOT/ghq/github.com/$TEST_REPO_ID"
  jq_prefix=$(dirname "$(dirname "$(command -v jq)")")
  mkdir -p "$COREUTILS/bin" "$FAKE_DOLT_ROOT/bin" "$TEST_REPO/.beads"
  printf '%s\n' '{"dolt_database":"test_beads"}' >"$TEST_REPO/.beads/metadata.json"
  printf 'BEADS_LINEAR_SYNC_REPOS=%q\n' "$TEST_REPO_ID" >"$ENV_FILE"
  canonical_test_repo="$(cd "$TEST_REPO" && pwd -P)"
  repo_slug="${TEST_REPO_ID//\//_}"
  repo_slug="${repo_slug//[^[:alnum:]_.-]/_}"
  CHECKPOINT_FILE="$STATE_HOME/beads-linear-sync/last-success-$repo_slug"
  export DOTFILES_ENV_FILE="$ENV_FILE"
  export DOLT_LOG FSCK_TIMEOUT_LOG
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
    printf '%s\n' "${BEADS_FSCK_TIMEOUT:-}" >>"$FSCK_TIMEOUT_LOG"
    count=0
    if [ -s "$SYNC_COUNT" ]; then
      count=$(<"$SYNC_COUNT")
    fi
    count=$((count + 1))
    printf '%s\n' "$count" >"$SYNC_COUNT"
    if [ "${FAKE_LINEAR_MODE:-}" = "final-failure" ] && [ "$count" -eq 2 ]; then
      exit 42
    fi
    if [ "${FAKE_LINEAR_MODE:-}" = "initial-federation-failure" ] && [ "$count" -eq 1 ]; then
      exit 41
    fi
    ;;
  "linear status")
    printf '{"last_sync":"%s"}\n' "${FAKE_LAST_SYNC:-}"
    ;;
  "linear sync")
    case "${FAKE_LINEAR_MODE:-success}" in
      rate-limit)
        printf '%s\n' 'rate limit circuit breaker is open'
        ;;
      hard-failure)
        exit 23
        ;;
      pull-failure)
        if [[ " $* " != *" --push "* ]]; then
          exit 23
        fi
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
  printf '%s\n' '#!/usr/bin/env bash' 'printf '\''%s\n'\'' "$*" >>"$DOLT_LOG"' 'exit 0' >"$FAKE_DOLT_ROOT/bin/dolt"
  chmod +x "$FAKE_DOLT_ROOT/bin/dolt"
  sed \
    -e "s|@bd@|$FAKE_BD|g" \
    -e "s|@dolt@|$FAKE_DOLT_ROOT|g" \
    -e 's|@linear@|/usr/bin/false|g' \
    -e 's|@linearWorkspace@|test-workspace|g' \
    -e 's|@linearTeamId@|test-team|g' \
    -e "s|@coreutils@|$COREUTILS|g" \
    -e 's|@gawk@|/usr|g' \
    -e "s|@jq@|$jq_prefix|g" \
    "$SCRIPT" >"$RENDERED_SCRIPT"
}

cleanup_reconciliation() {
  unset DOLT_LOG DOTFILES_ENV_FILE FSCK_TIMEOUT_LOG
  rm -rf "$TEST_ROOT"
}

Before 'setup_reconciliation'
After 'cleanup_reconciliation'

It 'runs both federations around pull and delta push before checkpointing'
When run env COMMAND_LOG="$COMMAND_LOG" SYNC_COUNT="$SYNC_COUNT" XDG_STATE_HOME="$STATE_HOME" HOME="$TEST_ROOT" LINEAR_API_KEY=test bash "$RENDERED_SCRIPT"
The status should be success
The output should include 'Pushing changed active Beads'
The file "$CHECKPOINT_FILE" should be exist
The contents of file "$COMMAND_LOG" should include 'linear sync --pull --state all --relations --no-wait'
The contents of file "$COMMAND_LOG" should include 'linear sync --push --issues df-test --no-wait'
The contents of file "$FSCK_TIMEOUT_LOG" should equal "300s
300s"
End

It 'splits a large outbound delta into bounded batches'
batch_json="$(jq -nc '[range(1;13) | {id:("df-" + tostring),status:"open",updated_at:"2099-01-01T00:00:00Z"}]')"
When run env COMMAND_LOG="$COMMAND_LOG" SYNC_COUNT="$SYNC_COUNT" FAKE_LIST_JSON="$batch_json" XDG_STATE_HOME="$STATE_HOME" HOME="$TEST_ROOT" LINEAR_API_KEY=test bash "$RENDERED_SCRIPT"
The status should be success
The output should include 'batch 1/2'
The output should include 'batch 2/2'
The contents of file "$COMMAND_LOG" should include 'linear sync --push --issues df-1,df-2,df-3,df-4,df-5,df-6,df-7,df-8,df-9,df-10 --no-wait'
The contents of file "$COMMAND_LOG" should include 'linear sync --push --issues df-11,df-12 --no-wait'
End

It 'defers a Linear rate limit without advancing the checkpoint'
When run env COMMAND_LOG="$COMMAND_LOG" SYNC_COUNT="$SYNC_COUNT" FAKE_LINEAR_MODE=rate-limit XDG_STATE_HOME="$STATE_HOME" HOME="$TEST_ROOT" LINEAR_API_KEY=test bash "$RENDERED_SCRIPT"
The status should be success
The output should include 'next 900-second run will retry'
The file "$CHECKPOINT_FILE" should not be exist
End

It 'fails closed after an ordinary Linear pull failure'
When run env COMMAND_LOG="$COMMAND_LOG" SYNC_COUNT="$SYNC_COUNT" FAKE_LINEAR_MODE=pull-failure FAKE_LAST_SYNC=2026-08-24T10:39:54Z XDG_STATE_HOME="$STATE_HOME" HOME="$TEST_ROOT" LINEAR_API_KEY=test bash "$RENDERED_SCRIPT"
The status should equal 23
The output should include 'Linear pull failed with status 23'
The output should not include 'Pushing changed active Beads'
The file "$CHECKPOINT_FILE" should not be exist
The contents of file "$DOLT_LOG" should include "DELETE FROM local_metadata"
The contents of file "$DOLT_LOG" should include "REPLACE INTO local_metadata"
End

It 'propagates a Linear push failure without advancing the checkpoint'
When run env COMMAND_LOG="$COMMAND_LOG" SYNC_COUNT="$SYNC_COUNT" FAKE_LINEAR_MODE=push-failure XDG_STATE_HOME="$STATE_HOME" HOME="$TEST_ROOT" LINEAR_API_KEY=test bash "$RENDERED_SCRIPT"
The status should equal 24
The output should include 'Linear push failed with status 24'
The file "$CHECKPOINT_FILE" should not be exist
End

It 'pushes a locally closed linked issue from a steady-state delta'
mkdir -p "$STATE_HOME/beads-linear-sync"
printf '%s\n' '2026-01-01T00:00:00Z' >"$CHECKPOINT_FILE"
When run env COMMAND_LOG="$COMMAND_LOG" SYNC_COUNT="$SYNC_COUNT" FAKE_LIST_JSON='[{"id":"df-closed","status":"closed","updated_at":"2099-01-01T00:00:00Z","external_ref":"https://linear.app/test/issue/TEST-1/closed"}]' XDG_STATE_HOME="$STATE_HOME" HOME="$TEST_ROOT" LINEAR_API_KEY=test bash "$RENDERED_SCRIPT"
The status should be success
The output should include 'Pushing changed active Beads'
The contents of file "$COMMAND_LOG" should include 'linear sync --push --issues df-closed --no-wait'
End

It 'fails closed without checkpointing when final Dolt federation fails'
When run env COMMAND_LOG="$COMMAND_LOG" SYNC_COUNT="$SYNC_COUNT" FAKE_LINEAR_MODE=final-failure XDG_STATE_HOME="$STATE_HOME" HOME="$TEST_ROOT" LINEAR_API_KEY=test bash "$RENDERED_SCRIPT"
The status should equal 42
The output should include 'Pushing changed active Beads'
The output should include 'Dolt post-sync federation failed with status 42'
The file "$CHECKPOINT_FILE" should not be exist
End

It 'fails closed before Linear reconciliation when initial Dolt federation fails'
When run env COMMAND_LOG="$COMMAND_LOG" SYNC_COUNT="$SYNC_COUNT" FAKE_LINEAR_MODE=initial-federation-failure XDG_STATE_HOME="$STATE_HOME" HOME="$TEST_ROOT" LINEAR_API_KEY=test bash "$RENDERED_SCRIPT"
The status should equal 41
The output should include 'Dolt pre-sync federation failed with status 41'
The output should not include 'Pushing changed active Beads'
The file "$CHECKPOINT_FILE" should not be exist
End

It 'fails closed when the repository list is absent'
When run env -u BEADS_LINEAR_SYNC_REPOS DOTFILES_ENV_FILE="$TEST_ROOT/missing" HOME="$TEST_ROOT" LINEAR_API_KEY=test bash "$RENDERED_SCRIPT"
The status should equal 1
The output should include 'BEADS_LINEAR_SYNC_REPOS is required'
End

It 'rejects an absolute checkout path instead of logging it'
printf 'BEADS_LINEAR_SYNC_REPOS=%q\n' '/private/checkout' >"$TEST_ROOT/invalid-dotenv"
When run env DOTFILES_ENV_FILE="$TEST_ROOT/invalid-dotenv" HOME="$TEST_ROOT" LINEAR_API_KEY=test bash "$RENDERED_SCRIPT"
The status should equal 1
The output should include 'Invalid org/repo entry'
The output should not include '/private/checkout'
End

It 'rejects an org/repo checkout that is not a Beads repository'
printf 'BEADS_LINEAR_SYNC_REPOS=%q\n' 'test/not-beads' >"$TEST_ROOT/invalid-dotenv"
mkdir -p "$TEST_ROOT/ghq/github.com/test/not-beads"
When run env DOTFILES_ENV_FILE="$TEST_ROOT/invalid-dotenv" HOME="$TEST_ROOT" LINEAR_API_KEY=test bash "$RENDERED_SCRIPT"
The status should equal 1
The output should include 'Configured checkout is not a Beads repository'
The output should not include 'test/not-beads'
End

It 'syncs comma-separated repositories with distinct checkpoints'
second_repo_id="test/repo-two"
second_repo="$TEST_ROOT/ghq/github.com/$second_repo_id"
mkdir -p "$second_repo/.beads"
printf '%s\n' '{"dolt_database":"test_beads_two"}' >"$second_repo/.beads/metadata.json"
canonical_second_repo="$(cd "$second_repo" && pwd -P)"
printf 'BEADS_LINEAR_SYNC_REPOS=%q,%q\n' "$TEST_REPO_ID" "$second_repo_id" >"$ENV_FILE"
second_repo_slug="${second_repo_id//\//_}"
second_repo_slug="${second_repo_slug//[^[:alnum:]_.-]/_}"
second_checkpoint="$STATE_HOME/beads-linear-sync/last-success-$second_repo_slug"
When run env COMMAND_LOG="$COMMAND_LOG" SYNC_COUNT="$SYNC_COUNT" XDG_STATE_HOME="$STATE_HOME" HOME="$TEST_ROOT" LINEAR_API_KEY=test bash "$RENDERED_SCRIPT"
The status should be success
The output should include 'repository 1/2'
The output should include 'repository 2/2'
The output should not include "$TEST_REPO_ID"
The output should not include "$second_repo_id"
The file "$CHECKPOINT_FILE" should be exist
The file "$second_checkpoint" should be exist
The contents of file "$COMMAND_LOG" should include "-C $canonical_test_repo"
The contents of file "$COMMAND_LOG" should include "-C $canonical_second_repo"
End

It 'continues to the next repository after one repository fails'
printf 'BEADS_LINEAR_SYNC_REPOS=%q,%q\n' 'test/not-beads' "$TEST_REPO_ID" >"$ENV_FILE"
When run env COMMAND_LOG="$COMMAND_LOG" SYNC_COUNT="$SYNC_COUNT" XDG_STATE_HOME="$STATE_HOME" HOME="$TEST_ROOT" LINEAR_API_KEY=test bash "$RENDERED_SCRIPT"
The status should equal 1
The output should include 'Configured checkout is not a Beads repository'
The output should not include 'test/not-beads'
The output should include 'Pushing changed active Beads'
The file "$CHECKPOINT_FILE" should be exist
End
End

Describe 'Home Manager service ownership'
It 'runs Linear every fifteen minutes while federation stays at five minutes on launchd'
When run bash -c "grep -F 'linearSyncIntervalSeconds = 900;' '$MODULE' >/dev/null && grep -F 'federationSyncIntervalSeconds = 300;' '$MODULE' >/dev/null && grep -F 'ThrottleInterval = linearSyncIntervalSeconds;' '$MODULE' >/dev/null && grep -F 'ThrottleInterval = federationSyncIntervalSeconds;' '$MODULE' >/dev/null && grep -F 'PATH = linearSyncPath;' '$MODULE' >/dev/null"
The status should be success
End

It 'restricts the Linear writer to Kyber'
When run bash -c "grep -F 'linearSyncEnabled = isKyber;' '$MODULE' >/dev/null && grep -F 'launchd.agents.dolt-linear-sync = lib.mkIf (pkgs.stdenv.isDarwin && linearSyncEnabled)' '$MODULE' >/dev/null && grep -F 'systemd.user.services.dolt-linear-sync = lib.mkIf (pkgs.stdenv.isLinux && linearSyncEnabled)' '$MODULE' >/dev/null"
The status should be success
End

It 'installs the Kyber Linux systemd timer'
When run bash -c "grep -F 'systemd.user.timers.dolt-linear-sync' '$MODULE' >/dev/null && grep -F 'OnCalendar = \"*-*-* *:00/15:00\";' '$MODULE' >/dev/null && grep -F 'X-SwitchMethod = \"restart\";' '$MODULE' >/dev/null"
The status should be success
End
End
End
