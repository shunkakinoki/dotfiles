#!/usr/bin/env bash
# shellcheck disable=SC2329,SC2016

Describe 'cliproxyapi backup scripts'
SCRIPTS_DIR="$PWD/home-manager/services/cliproxyapi/scripts"
NIX_MODULE="$PWD/home-manager/services/cliproxyapi/default.nix"

# Preprocess scripts once at describe-time
__PREPROCESSED_DIR=$(mktemp -d)
__COMMON_SCRIPT="$__PREPROCESSED_DIR/common.sh"
__HYDRATE_SCRIPT="$__PREPROCESSED_DIR/hydrate.sh"
__BACKUP_SCRIPT="$__PREPROCESSED_DIR/backup.sh"

# Preprocess common.sh
sed \
  -e 's|@aws@|aws|g' \
  -e 's|@sqlite3@|sqlite3|g' \
  -e 's|@tar@|tar|g' \
  -e 's|@objectstore_enabled@|true|g' \
  "$SCRIPTS_DIR/common.sh" >"$__COMMON_SCRIPT"
chmod +x "$__COMMON_SCRIPT"

# Preprocess hydrate.sh
sed \
  -e 's|@common@|'"$__COMMON_SCRIPT"'|g' \
  "$SCRIPTS_DIR/hydrate.sh" >"$__HYDRATE_SCRIPT"
chmod +x "$__HYDRATE_SCRIPT"

# Preprocess backup.sh
sed \
  -e 's|@common@|'"$__COMMON_SCRIPT"'|g' \
  "$SCRIPTS_DIR/backup.sh" >"$__BACKUP_SCRIPT"
chmod +x "$__BACKUP_SCRIPT"

__BACKUP_CHECK_SCRIPT="$__PREPROCESSED_DIR/backup-check.sh"
sed \
  -e 's|@common@|'"$__COMMON_SCRIPT"'|g' \
  "$SCRIPTS_DIR/backup-check.sh" >"$__BACKUP_CHECK_SCRIPT"
chmod +x "$__BACKUP_CHECK_SCRIPT"

Describe 'hydrate.sh'

setup() {
  mock_bin_setup aws
  TEMP_HOME=$(mktemp -d)
  mkdir -p "$TEMP_HOME/.cli-proxy-api/objectstore/auths"
  mkdir -p "$TEMP_HOME/dotfiles"

  # Create .env with test credentials
  cat >"$TEMP_HOME/dotfiles/.env" <<'ENV'
OBJECTSTORE_ACCESS_KEY=test_key
OBJECTSTORE_SECRET_KEY=test_secret
OBJECTSTORE_ENDPOINT=https://test.endpoint.com
ENV

  unset OBJECTSTORE_ACCESS_KEY
  unset OBJECTSTORE_SECRET_KEY
  unset OBJECTSTORE_ENDPOINT
}

cleanup() {
  rm -rf "$TEMP_HOME"
  mock_bin_cleanup
}

Before 'setup'
After 'cleanup'

It 'pulls from the configured S3 auth path'
When run bash -c 'HOME="'"$TEMP_HOME"'" bash "'"$__HYDRATE_SCRIPT"'" 2>&1; status=$?; cat "$MOCK_LOG" 2>/dev/null || true; exit "$status"'
The status should be success
The output should include 's3://cliproxyapi/auths/'
End

It 'uses OBJECTSTORE_BUCKET for hydrate paths'
cat >"$TEMP_HOME/dotfiles/.env" <<'ENV'
OBJECTSTORE_ACCESS_KEY=test_key
OBJECTSTORE_SECRET_KEY=test_secret
OBJECTSTORE_ENDPOINT=https://test.endpoint.com
OBJECTSTORE_BUCKET=custom-bucket
ENV
When run bash -c 'HOME="'"$TEMP_HOME"'" bash "'"$__HYDRATE_SCRIPT"'" 2>&1; status=$?; cat "$MOCK_LOG" 2>/dev/null || true; exit "$status"'
The status should be success
The output should include 's3://custom-bucket/auths/'
End

It 'leaves a populated auth cache untouched'
echo '{}' >"$TEMP_HOME/.cli-proxy-api/objectstore/auths/claude-test.json"
When run bash -c 'HOME="'"$TEMP_HOME"'" bash "'"$__HYDRATE_SCRIPT"'" 2>&1; status=$?; cat "$MOCK_LOG" 2>/dev/null || true; exit "$status"'
The status should be success
The output should not include 's3 sync'
End

It 'skips when credentials are missing'
rm -f "$TEMP_HOME/dotfiles/.env"
When run bash -c 'HOME="'"$TEMP_HOME"'" bash "'"$__HYDRATE_SCRIPT"'" 2>&1'
The status should be success
The output should include 'Missing S3 credentials'
End
End

Describe 'backup.sh'

setup() {
  mock_bin_setup aws
  # The analytics archive is streamed into `aws s3 cp -`, so the mock has to
  # drain stdin or the producing tar dies on SIGPIPE.
  cat >"$MOCK_BIN/aws" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
: "${MOCK_LOG:?MOCK_LOG must be set}"
printf '%s\n' "$0 $*" >>"$MOCK_LOG"
for arg in "$@"; do
  if [ "$arg" = "-" ]; then
    cat >/dev/null
    break
  fi
done
EOF
  chmod +x "$MOCK_BIN/aws"
  cat >"$MOCK_BIN/sqlite3" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
: "${MOCK_LOG:?MOCK_LOG must be set}"
printf '%s\n' "$0 $*" >>"$MOCK_LOG"

command="${*: -1}"
case "$command" in
  "VACUUM INTO '"*)
    snapshot_path="${command#VACUUM INTO \'}"
    snapshot_path="${snapshot_path%\'}"
    : >"$snapshot_path"
    ;;
  'PRAGMA integrity_check;')
    printf '%s\n' "${SQLITE_INTEGRITY_RESULT:-ok}"
    ;;
esac
EOF
  chmod +x "$MOCK_BIN/sqlite3"
  TEMP_HOME=$(mktemp -d)
  mkdir -p "$TEMP_HOME/.cli-proxy-api/objectstore/auths"
  mkdir -p "$TEMP_HOME/dotfiles"

  # Create .env with test credentials
  cat >"$TEMP_HOME/dotfiles/.env" <<'ENV'
OBJECTSTORE_ACCESS_KEY=test_key
OBJECTSTORE_SECRET_KEY=test_secret
OBJECTSTORE_ENDPOINT=https://test.endpoint.com
ENV

  unset OBJECTSTORE_ACCESS_KEY
  unset OBJECTSTORE_SECRET_KEY
  unset OBJECTSTORE_ENDPOINT
}

seed_manager_data() {
  mkdir -p "$TEMP_HOME/.cpa-manager-plus"
  touch "$TEMP_HOME/.cpa-manager-plus/usage.sqlite"
  touch "$TEMP_HOME/.cpa-manager-plus/data.key"
}

cleanup() {
  rm -rf "$TEMP_HOME"
  mock_bin_cleanup
}

Before 'setup'
After 'cleanup'

It 'skips when auth directory is empty'
When run bash -c 'HOME="'"$TEMP_HOME"'" bash "'"$__BACKUP_SCRIPT"'" auth 2>&1'
The status should be success
The output should include 'No auth files to backup'
End

It 'pushes to S3 when auth files exist'
touch "$TEMP_HOME/.cli-proxy-api/objectstore/auths/test-auth.json"
When run bash -c 'HOME="'"$TEMP_HOME"'" bash "'"$__BACKUP_SCRIPT"'" auth 2>&1; status=$?; cat "$MOCK_LOG" 2>/dev/null || true; exit "$status"'
The status should be success
The output should include 's3://cliproxyapi/auths/'
End

It 'hands container-owned auth files back to the backup user before syncing'
touch "$TEMP_HOME/.cli-proxy-api/objectstore/auths/test-auth.json"
cat >"$MOCK_BIN/docker" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "docker $*" >>"$MOCK_LOG"
EOF
chmod +x "$MOCK_BIN/docker"
When run bash -c 'HOME="'"$TEMP_HOME"'" bash "'"$__BACKUP_SCRIPT"'" auth 2>&1; status=$?; cat "$MOCK_LOG" 2>/dev/null || true; exit "$status"'
The status should be success
The output should include 'docker exec cliproxyapi find /root/.cli-proxy-api/objectstore/auths'
The output should include "! -uid $(id -u)"
The output should include "-exec chown $(id -u):$(id -g)"
End

It 'uses OBJECTSTORE_BUCKET for backup paths'
cat >"$TEMP_HOME/dotfiles/.env" <<'ENV'
OBJECTSTORE_ACCESS_KEY=test_key
OBJECTSTORE_SECRET_KEY=test_secret
OBJECTSTORE_ENDPOINT=https://test.endpoint.com
OBJECTSTORE_BUCKET=custom-bucket
ENV
touch "$TEMP_HOME/.cli-proxy-api/objectstore/auths/test-auth.json"
When run bash -c 'HOME="'"$TEMP_HOME"'" bash "'"$__BACKUP_SCRIPT"'" auth 2>&1; status=$?; cat "$MOCK_LOG" 2>/dev/null || true; exit "$status"'
The status should be success
The output should include 's3://custom-bucket/auths/'
End

It 'leaves the analytics database alone in auth mode'
touch "$TEMP_HOME/.cli-proxy-api/objectstore/auths/test-auth.json"
seed_manager_data
When run bash -c 'HOME="'"$TEMP_HOME"'" bash "'"$__BACKUP_SCRIPT"'" auth 2>&1; status=$?; cat "$MOCK_LOG" 2>/dev/null || true; exit "$status"'
The status should be success
The output should include 's3://cliproxyapi/auths/'
The output should not include 'CPA Manager Plus analytics'
The output should not include 'VACUUM INTO'
The output should not include 'cpa-manager-plus/'
End

It 'defaults to auth mode so a stray invocation cannot copy the analytics database'
touch "$TEMP_HOME/.cli-proxy-api/objectstore/auths/test-auth.json"
seed_manager_data
When run bash -c 'HOME="'"$TEMP_HOME"'" bash "'"$__BACKUP_SCRIPT"'" 2>&1; status=$?; cat "$MOCK_LOG" 2>/dev/null || true; exit "$status"'
The status should be success
The output should include 's3://cliproxyapi/auths/'
The output should not include 'cpa-manager-plus/'
End

It 'rejects an unknown mode'
When run bash -c 'HOME="'"$TEMP_HOME"'" bash "'"$__BACKUP_SCRIPT"'" hourly 2>&1'
The status should eq 2
The output should include 'usage: backup.sh [auth|full]'
End

It 'uploads a consistent CPA Manager Plus archive in full mode'
seed_manager_data
When run bash -c 'HOME="'"$TEMP_HOME"'" bash "'"$__BACKUP_SCRIPT"'" full 2>&1; status=$?; cat "$MOCK_LOG" 2>/dev/null || true; exit "$status"'
The status should be success
The output should include "VACUUM INTO '"
The output should include 'PRAGMA integrity_check;'
The output should match pattern '*s3://cliproxyapi/cpa-manager-plus/analytics-backup-??.tar.gz*'
The output should include 'cpa-manager-plus/analytics-backup.tar.gz'
End

It 'promotes the archive with the low-level S3 copy API'
seed_manager_data
When run bash -c 'HOME="'"$TEMP_HOME"'" bash "'"$__BACKUP_SCRIPT"'" full 2>&1; status=$?; cat "$MOCK_LOG" 2>/dev/null || true; exit "$status"'
The status should be success
The output should match pattern '*aws s3 cp*--only-show-errors - s3://cliproxyapi/cpa-manager-plus/analytics-backup-??.tar.gz*'
The output should match pattern '*aws s3api copy-object*--bucket=cliproxyapi*--key=cpa-manager-plus/analytics-backup.tar.gz*--copy-source=cliproxyapi/cpa-manager-plus/analytics-backup-??.tar.gz*'
End

It 'stages the snapshot where the caller asks'
seed_manager_data
STAGING_DIR="$TEMP_HOME/staging"
When run bash -c 'HOME="'"$TEMP_HOME"'" CLIPROXY_BACKUP_STAGING_DIR="'"$STAGING_DIR"'" bash "'"$__BACKUP_SCRIPT"'" full 2>&1; status=$?; cat "$MOCK_LOG" 2>/dev/null || true; exit "$status"'
The status should be success
The output should include "$STAGING_DIR/cpa-manager-plus-backup."
End

It 'removes the staging directory when terminated mid-snapshot'
seed_manager_data
STAGING_DIR="$TEMP_HOME/staging"
mkdir -p "$STAGING_DIR"
cat >"$MOCK_BIN/sqlite3" <<'EOF'
#!/usr/bin/env bash
touch "$SQLITE_STARTED"
exec sleep 30
EOF
chmod +x "$MOCK_BIN/sqlite3"
# Mirror a systemd start timeout: SIGTERM the whole process group, then
# SIGKILL whatever is left once the main process has exited.
When run bash -c 'set -m; export HOME="'"$TEMP_HOME"'" CLIPROXY_BACKUP_STAGING_DIR="'"$STAGING_DIR"'" SQLITE_STARTED="'"$TEMP_HOME"'/started"; bash "'"$__BACKUP_SCRIPT"'" full >/dev/null 2>&1 & pid=$!; for _ in $(seq 100); do [ -f "$SQLITE_STARTED" ] && break; sleep 0.1; done; kill -TERM -- "-$pid"; wait "$pid"; status=$?; kill -KILL -- "-$pid" 2>/dev/null; ls -A "'"$STAGING_DIR"'"; exit "$status"'
The status should eq 143
The output should eq ''
End

It 'fails closed and skips analytics uploads when the snapshot is corrupt'
seed_manager_data
When run bash -c 'HOME="'"$TEMP_HOME"'" SQLITE_INTEGRITY_RESULT=corrupt bash "'"$__BACKUP_SCRIPT"'" full 2>&1; status=$?; cat "$MOCK_LOG" 2>/dev/null || true; exit "$status"'
The status should be failure
The output should include 'SQLite snapshot failed its integrity check'
The output should not include 's3://cliproxyapi/cpa-manager-plus/'
End

It 'skips when credentials are missing'
rm -f "$TEMP_HOME/dotfiles/.env"
touch "$TEMP_HOME/.cli-proxy-api/objectstore/auths/test-auth.json"
When run bash -c 'HOME="'"$TEMP_HOME"'" bash "'"$__BACKUP_SCRIPT"'" full 2>&1'
The status should be success
The output should include 'Missing S3 credentials'
End
End

Describe 'backup-check.sh'
setup() {
  mock_bin_setup systemctl
  S3_DIR=$(mktemp -d)
  export S3_DIR
  cat >"$MOCK_BIN/aws" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "aws $*" >>"$MOCK_LOG"
for arg in "$@"; do
  case "$arg" in
    s3://*) object="${arg##*/}" ;;
  esac
done
[ -f "$S3_DIR/$object" ] || exit 1
cat "$S3_DIR/$object"
EOF
  chmod +x "$MOCK_BIN/aws"
  cat >"$MOCK_BIN/systemctl" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "systemctl $*" >>"$MOCK_LOG"
if [ -n "${SYSTEMCTL_ERROR:-}" ]; then
  echo "$SYSTEMCTL_ERROR" >&2
  exit 1
fi
if [ "${*: -1}" = "${FAILED_UNIT:-}" ]; then
  echo failed
else
  echo active
fi
EOF
  chmod +x "$MOCK_BIN/systemctl"
  cat >"$MOCK_BIN/notify" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "notify $1 | $2" >>"$MOCK_LOG"
EOF
  chmod +x "$MOCK_BIN/notify"
  TEMP_HOME=$(mktemp -d)
  AUTH="$TEMP_HOME/.cli-proxy-api/objectstore/auths"
  mkdir -p "$AUTH" "$TEMP_HOME/dotfiles"
  cat >"$TEMP_HOME/dotfiles/.env" <<'ENV'
OBJECTSTORE_ACCESS_KEY=test_key
OBJECTSTORE_SECRET_KEY=test_secret
OBJECTSTORE_ENDPOINT=https://test.endpoint.com
ENV
  unset OBJECTSTORE_ACCESS_KEY OBJECTSTORE_SECRET_KEY OBJECTSTORE_ENDPOINT
}

cleanup() {
  rm -rf "$TEMP_HOME" "$S3_DIR"
  mock_bin_cleanup
}

seed_auth() {
  printf '%s' "$2" >"$AUTH/$1"
  touch -t 202601010000 "$AUTH/$1"
}

run_check() {
  bash -c 'HOME="'"$TEMP_HOME"'" CLIPROXY_NOTIFY="'"$MOCK_BIN"'/notify" bash "'"$__BACKUP_CHECK_SCRIPT"'" 2>&1; status=$?; cat "$MOCK_LOG"; exit "$status"'
}

Before 'setup'
After 'cleanup'

It 'passes when every settled auth file matches S3'
seed_auth a.json live
printf '%s' live >"$S3_DIR/a.json"
When call run_check
The status should be success
The output should include 'S3 auth backup is current'
The output should not include 'notify'
End

It 'alerts when the S3 copy differs'
seed_auth a.json live
printf '%s' revoked >"$S3_DIR/a.json"
When call run_check
The status should be failure
The output should include 'notify cliproxy S3 backup stale | a.json: S3 copy differs'
End

It 'alerts when a file never reached S3'
seed_auth a.json live
When call run_check
The status should be failure
The output should include 'a.json: missing from S3'
End

It 'gives freshly written files time to upload'
printf '%s' live >"$AUTH/a.json"
When call run_check
The status should be success
The output should include 'S3 auth backup is current'
End

It 'alerts when a backup unit has failed'
FAILED_UNIT=cliproxyapi-backup-auth.path
export FAILED_UNIT
When call run_check
The status should be failure
The output should include 'cliproxyapi-backup-auth.path failed'
End

It 'alerts when systemd cannot be queried instead of assuming units are healthy'
SYSTEMCTL_ERROR='Failed to connect to user scope bus'
export SYSTEMCTL_ERROR
When call run_check
The status should be failure
The output should include 'cliproxyapi-backup.service: cannot query systemd: Failed to connect to user scope bus'
End

It 'never downloads into the auth directory'
seed_auth a.json live
printf '%s' revoked >"$S3_DIR/a.json"
When call run_check
The status should be failure
The output should not include 's3 sync'
The output should include 's3://cliproxyapi/auths/a.json -'
The contents of file "$AUTH/a.json" should equal 'live'
End
End

Describe 'backup scheduling'
It 'keeps the auth backup running through token refresh bursts'
When run bash -c "sed -n '/systemd.user.services.cliproxyapi-backup-auth =/,/^  };/p' '$NIX_MODULE'; sed -n '/systemd.user.timers.cliproxyapi-backup-auth =/,/^  };/p' '$NIX_MODULE'"
The status should be success
The output should include 'StartLimitIntervalSec = 0;'
The output should include 'OnUnitActiveSec = "15min"'
The output should include 'pkgs.docker'
End

It 'runs the drift check hourly on kyber only'
When run bash -c "sed -n '/systemd.user.timers.cliproxyapi-backup-check =/,/^  };/p' '$NIX_MODULE'; grep 'cliproxyapi-backup-check = lib.mkIf objectstoreEnabled' '$NIX_MODULE'"
The status should be success
The output should include 'OnCalendar = "*:30"'
The output should include 'Unit = "cliproxyapi-backup-check.service"'
The output should include 'systemd.user.services.cliproxyapi-backup-check = lib.mkIf objectstoreEnabled'
The output should include 'systemd.user.timers.cliproxyapi-backup-check = lib.mkIf objectstoreEnabled'
End

It 'gives the drift check the host systemctl'
When run bash -c "sed -n '/systemd.user.services.cliproxyapi-backup-check =/,/^  };/p' '$NIX_MODULE'"
The status should be success
The output should include '}:/usr/bin";'
The output should not include 'pkgs.systemd'
End

It 'gives the auth-file watchers the auth-only entrypoint'
When run bash -c "sed -n '/systemd.user.services.cliproxyapi-backup-auth =/,/^  };/p' '$NIX_MODULE'"
The status should be success
The output should include '${backupScript} auth'
The output should not include 'pkgs.sqlite'
The output should not include 'pkgs.gnutar'
End

It 'points the Linux path unit at the auth-only service'
When run bash -c "sed -n '/systemd.user.paths.cliproxyapi-backup-auth =/,/^  };/p' '$NIX_MODULE'"
The status should be success
The output should include 'PathChanged'
The output should include 'cliproxyapi-backup-auth.service'
End

It 'bounds the analytics backup so a stuck snapshot surfaces as a failure'
When run bash -c "sed -n '/systemd.user.services.cliproxyapi-backup =/,/^  };/p' '$NIX_MODULE'"
The status should be success
The output should include 'TimeoutStartSec = "2h";'
End

It 'keeps the analytics snapshot on wall-clock schedules only'
When run bash -c "sed -n '/systemd.user.services.cliproxyapi-backup =/,/^  };/p' '$NIX_MODULE'; sed -n '/systemd.user.timers.cliproxyapi-backup =/,/^  };/p' '$NIX_MODULE'"
The status should be success
The output should include 'OnCalendar = "hourly"'
The output should include '${backupScript} full'
The output should include 'Unit = "cliproxyapi-backup.service"'
The output should not include 'PathChanged'
End

It 'keeps OAuth auth sync and backups on kyber only'
When run bash -c "grep -E 'objectstoreEnabled =|lib.mkIf objectstoreEnabled|launchd.agents' '$NIX_MODULE'"
The status should be success
The output should include 'objectstoreEnabled = pkgs.stdenv.hostPlatform.isLinux && host.isKyber;'
The output should include 'home.activation.hydrateCliproxyAuths = lib.mkIf objectstoreEnabled'
The output should include 'systemd.user.paths.cliproxyapi-backup-auth = lib.mkIf objectstoreEnabled'
The output should include 'systemd.user.services.cliproxyapi-backup-auth = lib.mkIf objectstoreEnabled'
The output should include 'systemd.user.services.cliproxyapi-backup = lib.mkIf objectstoreEnabled'
The output should include 'systemd.user.timers.cliproxyapi-backup = lib.mkIf objectstoreEnabled'
The output should include 'launchd.agents.cliproxyapi ='
The output should not include 'launchd.agents.cliproxyapi-'
End
End

Describe 'objectstore host gate'
setup() {
  mock_bin_setup aws
  TEMP_HOME=$(mktemp -d)
  mkdir -p "$TEMP_HOME/.cli-proxy-api/objectstore/auths" "$TEMP_HOME/dotfiles"
  cat >"$TEMP_HOME/dotfiles/.env" <<'ENV'
OBJECTSTORE_ACCESS_KEY=test_key
OBJECTSTORE_SECRET_KEY=test_secret
OBJECTSTORE_ENDPOINT=https://test.endpoint.com
ENV
  touch "$TEMP_HOME/.cli-proxy-api/objectstore/auths/test-auth.json"
  unset OBJECTSTORE_ACCESS_KEY OBJECTSTORE_SECRET_KEY OBJECTSTORE_ENDPOINT
  DISABLED_DIR=$(mktemp -d)
  sed \
    -e 's|@aws@|aws|g' \
    -e 's|@sqlite3@|sqlite3|g' \
    -e 's|@tar@|tar|g' \
    -e 's|@objectstore_enabled@|false|g' \
    "$SCRIPTS_DIR/common.sh" >"$DISABLED_DIR/common.sh"
  sed -e 's|@common@|'"$DISABLED_DIR/common.sh"'|g' "$SCRIPTS_DIR/hydrate.sh" >"$DISABLED_DIR/hydrate.sh"
  sed -e 's|@common@|'"$DISABLED_DIR/common.sh"'|g' "$SCRIPTS_DIR/backup.sh" >"$DISABLED_DIR/backup.sh"
}

cleanup() {
  rm -rf "$TEMP_HOME" "$DISABLED_DIR"
  mock_bin_cleanup
}

Before 'setup'
After 'cleanup'

It 'ignores S3 credentials in hydrate on hosts without the objectstore'
When run bash -c 'HOME="'"$TEMP_HOME"'" bash "'"$DISABLED_DIR/hydrate.sh"'" 2>&1; cat "$MOCK_LOG" 2>/dev/null || true'
The status should be success
The output should include 'Missing S3 credentials'
The output should not include 's3://'
End

It 'ignores S3 credentials in backup on hosts without the objectstore'
When run bash -c 'HOME="'"$TEMP_HOME"'" bash "'"$DISABLED_DIR/backup.sh"'" full 2>&1; cat "$MOCK_LOG" 2>/dev/null || true'
The status should be success
The output should include 'Missing S3 credentials'
The output should not include 's3://'
End
End

# Cleanup preprocessed scripts at end
cleanup_preprocessed() {
  rm -rf "$__PREPROCESSED_DIR"
}
AfterAll 'cleanup_preprocessed'

End
