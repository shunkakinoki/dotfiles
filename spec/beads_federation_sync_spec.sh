#!/usr/bin/env bash
# shellcheck disable=SC2016,SC2329

Describe 'Beads Dolt federation synchronization'
SCRIPT="$PWD/home-manager/services/dolt/federation-sync.sh"
MODULE="$PWD/home-manager/services/dolt/default.nix"

Describe 'script properties'
It 'uses strict bash mode and validates after placeholder replacement'
When run bash -c "grep -F 'set -euo pipefail' '$SCRIPT' >/dev/null && sed 's|@[A-Za-z_][A-Za-z0-9_]*@|/usr|g' '$SCRIPT' | bash -n"
The status should be success
End

It 'loads machine-local scope without exposing a tracked repository'
When run bash -c "grep -F 'DOTFILES_ENV_FILE:-\$HOME/dotfiles/.env' '$SCRIPT' >/dev/null && grep -F 'BEADS_SYNC_REPOS:-\${BEADS_LINEAR_SYNC_REPOS:-}' '$SCRIPT' >/dev/null && ! grep -F '@repoDir@' '$SCRIPT' >/dev/null"
The status should be success
End

It 'gives fsck a measured budget below the per-repository deadline'
When run bash -c "grep -F 'federation_timeout_seconds=360' '$SCRIPT' >/dev/null && grep -F 'federation_fsck_timeout=300s' '$SCRIPT' >/dev/null && grep -F '@coreutils@/bin/timeout --kill-after=30s \"\$federation_timeout_seconds\"' '$SCRIPT' >/dev/null && grep -F '@coreutils@/bin/env BEADS_FSCK_TIMEOUT=\"\$federation_fsck_timeout\"' '$SCRIPT' >/dev/null && sync=\$(grep -n '@coreutils@/bin/timeout --kill-after=30s' '$SCRIPT' | cut -d: -f1); checkpoint=\$(grep -n '\"\$cycle_started\" >\"\$sync_checkpoint_file.tmp\"' '$SCRIPT' | cut -d: -f1); test \"\$checkpoint\" -gt \"\$sync\""
The status should be success
End

It 'shares the repository lock with Linear reconciliation'
When run bash -c "grep -F 'reconciliation_state_dir=\"\${XDG_STATE_HOME:-\$HOME/.local/state}/beads-reconciliation\"' '$SCRIPT' >/dev/null && grep -F 'reconcile-\$lock_repo_slug.lock' '$SCRIPT' >/dev/null && grep -F '@utilLinux@/bin/flock -w 900 9' '$SCRIPT' >/dev/null && grep -F 'reconciliation_lock_file=\"\$reconciliation_state_dir/reconcile-\$repo_slug.lock\"' \"$PWD/home-manager/services/dolt/linear-sync.sh\" >/dev/null"
The status should be success
End

It 'keeps the timer fixed-rate while systemd owns process-group cleanup'
When run bash -c "timer=\$(sed -n '/systemd.user.timers.dolt-federation-sync/,/^  };/p' '$MODULE'); grep -F 'OnCalendar = \"*-*-* *:00/5:00\";' <<<\"\$timer\" >/dev/null && ! grep -F 'OnUnitActiveSec' <<<\"\$timer\" >/dev/null && grep -F 'KillMode = \"control-group\";' '$MODULE' >/dev/null"
The status should be success
End
End

Describe 'runtime behavior'
setup_federation() {
  TEST_ROOT=$(mktemp -d)
  FAKE_BD="$TEST_ROOT/bd"
  FAKE_ENSURE_DATABASE="$TEST_ROOT/ensure-database.sh"
  RENDERED_SCRIPT="$TEST_ROOT/federation-sync.sh"
  COMMAND_LOG="$TEST_ROOT/commands.log"
  STATE_HOME="$TEST_ROOT/state"
  ENV_FILE="$TEST_ROOT/dotenv"
  COREUTILS="$TEST_ROOT/coreutils"
  UTIL_LINUX="$TEST_ROOT/util-linux"
  FSCK_TIMEOUT_LOG="$TEST_ROOT/fsck-timeouts.log"
  TEST_REPO_ID="test/repo-one"
  TEST_REPO="$TEST_ROOT/ghq/github.com/$TEST_REPO_ID"
  mkdir -p "$COREUTILS/bin" "$UTIL_LINUX/bin" "$TEST_REPO/.beads" "$TEST_ROOT/dotfiles/.beads"
  printf 'BEADS_SYNC_REPOS=%q\n' "$TEST_REPO_ID" >"$ENV_FILE"
  repo_slug="${TEST_REPO_ID//\//_}"
  CHECKPOINT_FILE="$STATE_HOME/beads-federation-sync/last-success-$repo_slug"
  export DOTFILES_ENV_FILE="$ENV_FILE" FSCK_TIMEOUT_LOG
  for command in date env mkdir mv sleep tail timeout; do
    ln -s "$(command -v "$command")" "$COREUTILS/bin/$command"
  done
  cat >"$UTIL_LINUX/bin/flock" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
test "$#" -eq 3
test "$1" = "-w"
wait_seconds="${FAKE_FLOCK_WAIT_SECONDS:-0}"
fd="$3"
if [ "$wait_seconds" = 0 ]; then
  exit 0
fi
exec python3 - "$wait_seconds" "$fd" <<'PY'
import fcntl
import sys
import time

deadline = time.monotonic() + float(sys.argv[1])
fd = int(sys.argv[2])
while True:
    try:
        fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
        raise SystemExit(0)
    except BlockingIOError:
        if time.monotonic() >= deadline:
            raise SystemExit(1)
        time.sleep(0.02)
PY
EOF
  chmod +x "$UTIL_LINUX/bin/flock"

  cat >"$FAKE_BD" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$COMMAND_LOG"
if [ "${1:-}" = "-C" ]; then
  shift 2
fi
case "${1:-} ${2:-}" in
  "migrate schema")
    exit "${FAKE_INITIALIZE_STATUS:-0}"
    ;;
  "ping ")
    exit "${FAKE_PING_STATUS:-0}"
    ;;
  "config get")
    if [ "${3:-}" = "sync.remote" ]; then
      printf '%s\n' 'git+https://example.invalid/org/repo.git'
      exit 0
    fi
    exit 1
    ;;
  "dolt remote")
    if [ "${3:-}" = "list" ]; then
      if [ "${FAKE_DOLT_REMOTE:-}" = "configured" ]; then
        printf '%s\n' 'origin git+https://example.invalid/org/repo.git'
      fi
      exit 0
    fi
    if [ "${3:-}" = "add" ]; then
      exit "${FAKE_REMOTE_ADD_STATUS:-0}"
    fi
    exit 1
    ;;
  "sync --yes")
    printf '%s\n' "${BEADS_FSCK_TIMEOUT:-}" >>"$FSCK_TIMEOUT_LOG"
    exit "${FAKE_SYNC_STATUS:-0}"
    ;;
  "ready --json")
    exit "${FAKE_READY_STATUS:-0}"
    ;;
esac
EOF
  chmod +x "$FAKE_BD"
  cat >"$FAKE_ENSURE_DATABASE" <<'EOF'
#!/usr/bin/env bash
printf 'ensure-database\n' >>"$COMMAND_LOG"
exit "${FAKE_PROVISION_STATUS:-0}"
EOF
  sed \
    -e "s|@bd@|$FAKE_BD|g" \
    -e "s|@coreutils@|$COREUTILS|g" \
    -e "s|@utilLinux@|$UTIL_LINUX|g" \
    -e "s|@ensureDatabaseScript@|$FAKE_ENSURE_DATABASE|g" \
    "$SCRIPT" >"$RENDERED_SCRIPT"
}

cleanup_federation() {
  unset DOTFILES_ENV_FILE
  rm -rf "$TEST_ROOT"
}

Before 'setup_federation'
After 'cleanup_federation'

It 'writes a checkpoint after a successful federation'
When run env COMMAND_LOG="$COMMAND_LOG" XDG_STATE_HOME="$STATE_HOME" HOME="$TEST_ROOT" bash "$RENDERED_SCRIPT"
The status should be success
The output should include 'Dolt federation complete'
The file "$CHECKPOINT_FILE" should be exist
The file "$STATE_HOME/beads-federation-sync/last-success-dotfiles" should be exist
The contents of file "$COMMAND_LOG" should include '/dotfiles ping'
The contents of file "$COMMAND_LOG" should include 'sync --yes --json'
The contents of file "$FSCK_TIMEOUT_LOG" should include '300s'
The contents of file "$COMMAND_LOG" should include 'ready --json'
The contents of file "$COMMAND_LOG" should include 'dolt remote add origin git+https://example.invalid/org/repo.git --allow-git-origin'
End

It 'propagates a federation failure without advancing the checkpoint'
When run env COMMAND_LOG="$COMMAND_LOG" FAKE_SYNC_STATUS=42 XDG_STATE_HOME="$STATE_HOME" HOME="$TEST_ROOT" bash "$RENDERED_SCRIPT"
The status should equal 42
The output should include 'Repository federation failed with status 42'
The file "$CHECKPOINT_FILE" should not be exist
End

It 'does not synchronize or claim readiness after provisioning fails'
When run env COMMAND_LOG="$COMMAND_LOG" FAKE_PROVISION_STATUS=1 XDG_STATE_HOME="$STATE_HOME" HOME="$TEST_ROOT" bash "$RENDERED_SCRIPT"
The status should equal 1
The output should include 'Database provisioning failed'
The file "$CHECKPOINT_FILE" should not be exist
The contents of file "$COMMAND_LOG" should not include 'sync --yes'
End

It 'does not synchronize or checkpoint when Beads initialization fails'
When run env COMMAND_LOG="$COMMAND_LOG" FAKE_INITIALIZE_STATUS=1 XDG_STATE_HOME="$STATE_HOME" HOME="$TEST_ROOT" bash "$RENDERED_SCRIPT"
The status should equal 1
The output should include 'Beads database initialization failed'
The file "$CHECKPOINT_FILE" should not be exist
The contents of file "$COMMAND_LOG" should not include 'ping'
The contents of file "$COMMAND_LOG" should not include 'sync --yes'
End

It 'does not synchronize a database that Beads cannot open'
When run env COMMAND_LOG="$COMMAND_LOG" FAKE_PING_STATUS=1 XDG_STATE_HOME="$STATE_HOME" HOME="$TEST_ROOT" bash "$RENDERED_SCRIPT"
The status should equal 1
The output should include 'Beads connectivity verification'
The file "$CHECKPOINT_FILE" should not be exist
The contents of file "$COMMAND_LOG" should not include 'sync --yes'
End

It 'does not advance readiness when work discovery fails after sync'
When run env COMMAND_LOG="$COMMAND_LOG" FAKE_READY_STATUS=1 XDG_STATE_HOME="$STATE_HOME" HOME="$TEST_ROOT" bash "$RENDERED_SCRIPT"
The status should equal 1
The output should include 'work-discovery verification'
The file "$CHECKPOINT_FILE" should not be exist
End

It 'fails closed when another reconciler owns the shared lock'
mkdir -p "$STATE_HOME/beads-reconciliation"
lock_file="$STATE_HOME/beads-reconciliation/reconcile-test%2Frepo-one.lock"
ready_file="$TEST_ROOT/lock-ready"
python3 -c 'import fcntl,pathlib,signal,sys; lock_handle=open(sys.argv[1], "w", encoding="utf-8"); fcntl.flock(lock_handle, fcntl.LOCK_EX); pathlib.Path(sys.argv[2]).touch(); signal.pause()' "$lock_file" "$ready_file" &
holder_pid=$!
while [ ! -e "$ready_file" ]; do sleep 0.02; done
When run bash -c "env COMMAND_LOG='$COMMAND_LOG' FAKE_FLOCK_WAIT_SECONDS=1 XDG_STATE_HOME='$STATE_HOME' HOME='$TEST_ROOT' bash '$RENDERED_SCRIPT'; status=\$?; kill '$holder_pid' 2>/dev/null || true; wait '$holder_pid' 2>/dev/null || true; exit \"\$status\""
The status should equal 75
The output should include 'Timed out waiting for the repository reconciliation lock'
The contents of file "$COMMAND_LOG" should not include 'ghq/github.com/test/repo-one sync --yes'
End

It 'rejects an absolute checkout path without logging it'
printf 'BEADS_SYNC_REPOS=%q\n' '/private/checkout' >"$ENV_FILE"
When run env COMMAND_LOG="$COMMAND_LOG" XDG_STATE_HOME="$STATE_HOME" HOME="$TEST_ROOT" bash "$RENDERED_SCRIPT"
The status should equal 1
The output should include 'Invalid org/repo entry'
The output should not include '/private/checkout'
End
End

Describe 'Home Manager ownership'
It 'loads the launchctl client environment from an external script'
When run bash -c "grep -F 'pkgs.replaceVars ./client-environment.sh' '$MODULE' >/dev/null && grep -F 'BEADS_DOLT_SERVER_HOST \"@doltServerHost@\"' '$PWD/home-manager/services/dolt/client-environment.sh' >/dev/null"
The status should be success
End

It 'publishes centralized server selection without legacy shared-server variables'
When run bash -c "grep -F 'BEADS_DOLT_SERVER_MODE = \"1\";' '$MODULE' >/dev/null && grep -F 'BEADS_DOLT_AUTO_START = \"0\";' '$MODULE' >/dev/null && ! grep -F 'BEADS_DOLT_SHARED_SERVER' '$MODULE' >/dev/null && ! grep -F 'BEADS_SHARED_SERVER_DIR' '$MODULE' >/dev/null && grep -F 'systemd.user.sessionVariables' '$MODULE' >/dev/null && grep -F 'launchd.agents.beads-dolt-client-environment' '$MODULE' >/dev/null"
The status should be success
End

It 'enables Dolt clients on Galactica, Kyber, Matic, and Kamino'
When run bash -c "grep -F 'clientEnabled = isGalactica || isKyber || isMatic || isKamino;' '$MODULE' >/dev/null && grep -F 'doltServerHost = \"127.0.0.1\";' '$MODULE' >/dev/null"
The status should be success
End

It 'serves Dolt locally on every client host'
When run bash -c "grep -F 'serverEnabled = clientEnabled;' '$MODULE' >/dev/null && grep -F 'pkgs.stdenv.hostPlatform.isLinux && serverEnabled' '$MODULE' >/dev/null && grep -F 'pkgs.stdenv.hostPlatform.isDarwin && serverEnabled' '$MODULE' >/dev/null"
The status should be success
End

It 'bounds Kyber Dolt backup writes without constraining other hosts'
When run bash -c "service=\$(sed -n '/systemd.user.services.dolt =/,/Install =/p' '$MODULE'); grep -F 'lib.optionalAttrs isKyber' <<<\"\$service\" >/dev/null && grep -F 'IOAccounting = true;' <<<\"\$service\" >/dev/null && grep -F 'IOWriteBandwidthMax = \"/ 20M\";' <<<\"\$service\" >/dev/null"
The status should be success
End

It 'federates every client host and publishes only from Kyber'
When run bash -c "grep -F 'federationSyncEnabled = clientEnabled;' '$MODULE' >/dev/null && grep -F 'publisherEnabled = isKyber;' '$MODULE' >/dev/null && grep -F 'federationHubHost = if federationHubEnabled then doltServerHost else \"kyber.tail950b36.ts.net\";' '$MODULE' >/dev/null && grep -F 'BEADS_FEDERATION_HUB = federationHubUrl;' '$MODULE' >/dev/null && ! grep -F 'dolt-backup-main = lib.mkIf (pkgs.stdenv.isLinux && serverEnabled)' '$MODULE' >/dev/null && ! grep -F 'dolt-backup-main = lib.mkIf (pkgs.stdenv.isDarwin && serverEnabled)' '$MODULE' >/dev/null"
The status should be success
End

It 'keeps federation on the five-minute boundary without an active-time duplicate'
When run bash -c "timer=\$(sed -n '/systemd.user.timers.dolt-federation-sync/,/^  };/p' '$MODULE'); grep -F 'OnBootSec = \"2min\";' <<<\"\$timer\" >/dev/null && grep -F 'OnCalendar = \"*-*-* *:00/5:00\";' <<<\"\$timer\" >/dev/null && ! grep -F 'OnUnitActiveSec' <<<\"\$timer\" >/dev/null && grep -F 'Persistent = true;' <<<\"\$timer\" >/dev/null"
The status should be success
End

It 'requires a Dolt version containing the gitblobstore missing-blob fix'
When run bash -c "grep -F 'doltMinVersion = \"2.2.2\";' '$MODULE' >/dev/null"
The status should be success
End
End
End
