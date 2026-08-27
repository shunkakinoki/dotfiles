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

It 'bounds federation and checkpoints only afterward'
When run bash -c "sync=\$(grep -n '@coreutils@/bin/timeout 120' '$SCRIPT' | cut -d: -f1); checkpoint=\$(grep -n '\"\$cycle_started\" >\"\$sync_checkpoint_file.tmp\"' '$SCRIPT' | cut -d: -f1); test \"\$checkpoint\" -gt \"\$sync\""
The status should be success
End
End

Describe 'runtime behavior'
setup_federation() {
  TEST_ROOT=$(mktemp -d)
  FAKE_BD="$TEST_ROOT/bd"
  RENDERED_SCRIPT="$TEST_ROOT/federation-sync.sh"
  COMMAND_LOG="$TEST_ROOT/commands.log"
  STATE_HOME="$TEST_ROOT/state"
  ENV_FILE="$TEST_ROOT/dotenv"
  COREUTILS="$TEST_ROOT/coreutils"
  TEST_REPO_ID="test/repo-one"
  TEST_REPO="$TEST_ROOT/ghq/github.com/$TEST_REPO_ID"
  mkdir -p "$COREUTILS/bin" "$TEST_REPO/.beads"
  printf 'BEADS_SYNC_REPOS=%q\n' "$TEST_REPO_ID" >"$ENV_FILE"
  repo_slug="${TEST_REPO_ID//\//_}"
  CHECKPOINT_FILE="$STATE_HOME/beads-federation-sync/last-success-$repo_slug"
  export DOTFILES_ENV_FILE="$ENV_FILE"
  for command in date mkdir mv sleep timeout; do
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
    exit "${FAKE_SYNC_STATUS:-0}"
    ;;
esac
EOF
  chmod +x "$FAKE_BD"
  sed \
    -e "s|@bd@|$FAKE_BD|g" \
    -e "s|@coreutils@|$COREUTILS|g" \
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
The contents of file "$COMMAND_LOG" should include 'sync --yes'
The contents of file "$COMMAND_LOG" should include 'dolt remote add origin git+https://example.invalid/org/repo.git --allow-git-origin'
End

It 'propagates a federation failure without advancing the checkpoint'
When run env COMMAND_LOG="$COMMAND_LOG" FAKE_SYNC_STATUS=42 XDG_STATE_HOME="$STATE_HOME" HOME="$TEST_ROOT" bash "$RENDERED_SCRIPT"
The status should equal 42
The output should include 'Repository federation failed with status 42'
The file "$CHECKPOINT_FILE" should not be exist
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

It 'enables Dolt clients on Galactica, Kyber, and Matic'
When run bash -c "grep -F 'clientEnabled = isGalactica || isKyber || isMatic;' '$MODULE' >/dev/null && grep -F 'doltServerHost = \"127.0.0.1\";' '$MODULE' >/dev/null"
The status should be success
End

It 'serves Dolt locally on every client host'
When run bash -c "grep -F 'serverEnabled = clientEnabled;' '$MODULE' >/dev/null && grep -F 'pkgs.stdenv.isLinux && serverEnabled' '$MODULE' >/dev/null && grep -F 'pkgs.stdenv.isDarwin && serverEnabled' '$MODULE' >/dev/null"
The status should be success
End

It 'federates every client host and publishes only from Kyber'
When run bash -c "grep -F 'federationSyncEnabled = clientEnabled;' '$MODULE' >/dev/null && grep -F 'publisherEnabled = isKyber;' '$MODULE' >/dev/null && ! grep -F 'dolt-backup-main = lib.mkIf (pkgs.stdenv.isLinux && serverEnabled)' '$MODULE' >/dev/null && ! grep -F 'dolt-backup-main = lib.mkIf (pkgs.stdenv.isDarwin && serverEnabled)' '$MODULE' >/dev/null"
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
