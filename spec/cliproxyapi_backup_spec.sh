#!/usr/bin/env bash
# shellcheck disable=SC2329,SC2016

Describe 'cliproxyapi backup scripts'
SCRIPTS_DIR="$PWD/home-manager/services/cliproxyapi/scripts"

# Preprocess scripts once at describe-time (not in setup)
# This ensures the preprocessed paths are available before any tests run
__PREPROCESSED_DIR=$(mktemp -d)
__BACKUP_AUTH_SCRIPT="$__PREPROCESSED_DIR/backup-auth.sh"
__BACKUP_RECOVER_SCRIPT="$__PREPROCESSED_DIR/backup-and-recover.sh"

# Preprocess backup-auth.sh
sed \
  -e 's|@aws@|aws|g' \
  -e 's|@rsync@|rsync|g' \
  -e 's|@bash@|bash|g' \
  -e 's|@sed@|sed|g' \
  "$SCRIPTS_DIR/backup-auth.sh" >"$__BACKUP_AUTH_SCRIPT"
chmod +x "$__BACKUP_AUTH_SCRIPT"

# Preprocess backup-and-recover.sh with path to preprocessed backup-auth.sh
sed \
  -e 's|@aws@|aws|g' \
  -e 's|@rsync@|rsync|g' \
  -e 's|@bash@|bash|g' \
  -e 's|@sed@|sed|g' \
  -e "s|@backupAuthScript@|$__BACKUP_AUTH_SCRIPT|g" \
  "$SCRIPTS_DIR/backup-and-recover.sh" >"$__BACKUP_RECOVER_SCRIPT"
chmod +x "$__BACKUP_RECOVER_SCRIPT"

Describe 'backup-auth.sh'

setup() {
  mock_bin_setup aws rsync
  TEMP_HOME=$(mktemp -d)
  mkdir -p "$TEMP_HOME/.cli-proxy-api/objectstore/auths"

  # Unset objectstore credentials to ensure clean test environment
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

It 'pulls from R2 but skips push when auth directory is empty'
When run bash -c 'HOME="'"$TEMP_HOME"'" OBJECTSTORE_ACCESS_KEY=key OBJECTSTORE_SECRET_KEY=secret OBJECTSTORE_ENDPOINT=https://example.com bash "'"$__BACKUP_AUTH_SCRIPT"'" 2>&1; cat "$MOCK_LOG" 2>/dev/null || true'
The status should be success
# Should pull from R2 auths/ and backup/auths/
The output should include 's3://cliproxyapi/auths/'
The output should include 's3://cliproxyapi/backup/auths/'
# Should NOT push to R2 since local is empty after pull
The output should not include 'Syncing auth files to R2'
End

It 'calls aws s3 sync when auth files exist'
touch "$TEMP_HOME/.cli-proxy-api/objectstore/auths/test-auth.json"
When run bash -c 'HOME="'"$TEMP_HOME"'" OBJECTSTORE_ACCESS_KEY=key OBJECTSTORE_SECRET_KEY=secret OBJECTSTORE_ENDPOINT=https://example.com bash "'"$__BACKUP_AUTH_SCRIPT"'" 2>&1; cat "$MOCK_LOG"'
The status should be success
The output should include 's3 sync'
The output should include 's3://cliproxyapi/backup/auths/'
End
End

Describe 'backup-and-recover.sh'

setup() {
  mock_bin_setup aws rsync
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

It 'sources .env and runs backup script'
When run bash -c 'HOME="'"$TEMP_HOME"'" bash "'"$__BACKUP_RECOVER_SCRIPT"'" 2>&1'
The status should be success
The output should include 'Starting backup'
The output should include 'Backup complete'
End
End

# Cleanup preprocessed scripts at end
cleanup_preprocessed() {
  rm -rf "$__PREPROCESSED_DIR"
}
AfterAll 'cleanup_preprocessed'

End
