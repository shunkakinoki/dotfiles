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
  ".backup '"*)
    snapshot_path="${command#.backup \'}"
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
The output should not include '.backup'
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
The output should include ".backup '"
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

Describe 'backup scheduling'
It 'gives the auth-file watchers the auth-only entrypoint'
When run bash -c "sed -n '/launchd.agents.cliproxyapi-backup-auth =/,/^  };/p' '$NIX_MODULE'; sed -n '/systemd.user.services.cliproxyapi-backup-auth =/,/^  };/p' '$NIX_MODULE'"
The status should be success
The output should include '"auth"'
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

It 'keeps the analytics snapshot on wall-clock schedules only'
When run bash -c "sed -n '/launchd.agents.cliproxyapi-backup =/,/^  };/p' '$NIX_MODULE'; sed -n '/systemd.user.services.cliproxyapi-backup =/,/^  };/p' '$NIX_MODULE'; sed -n '/systemd.user.timers.cliproxyapi-backup =/,/^  };/p' '$NIX_MODULE'"
The status should be success
The output should include 'StartCalendarInterval'
The output should include 'OnCalendar = "hourly"'
The output should include '${backupScript} full'
The output should include 'Unit = "cliproxyapi-backup.service"'
The output should not include 'WatchPaths'
End
End

# Cleanup preprocessed scripts at end
cleanup_preprocessed() {
  rm -rf "$__PREPROCESSED_DIR"
}
AfterAll 'cleanup_preprocessed'

End
