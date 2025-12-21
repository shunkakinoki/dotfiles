#!/usr/bin/env bash
# shellcheck disable=SC2329,SC2016

Describe 'cliproxyapi backup scripts'
SCRIPTS_DIR="$PWD/home-manager/services/cliproxyapi/scripts"

Describe 'backup-auth.sh'
SCRIPT="$SCRIPTS_DIR/backup-auth.sh"

setup() {
  mock_bin_setup aws
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

It 'skips backup when auth directory is empty'
When run bash -c 'env HOME="'"$TEMP_HOME"'" OBJECTSTORE_ACCESS_KEY=key OBJECTSTORE_SECRET_KEY=secret OBJECTSTORE_ENDPOINT=https://example.com bash '"$SCRIPT"'; cat "$MOCK_LOG" 2>/dev/null || true'
The status should be success
The output should eq ''
End

It 'calls aws s3 sync when auth files exist'
touch "$TEMP_HOME/.cli-proxy-api/objectstore/auths/test-auth.json"
When run bash -c 'env HOME="'"$TEMP_HOME"'" OBJECTSTORE_ACCESS_KEY=key OBJECTSTORE_SECRET_KEY=secret OBJECTSTORE_ENDPOINT=https://example.com bash '"$SCRIPT"' 2>&1; cat "$MOCK_LOG"'
The status should be success
The output should include 's3 sync'
The output should include 's3://cliproxyapi/backup/auths/'
End
End

Describe 'recover-auth.sh'
SCRIPT="$SCRIPTS_DIR/recover-auth.sh"

setup() {
  mock_bin_setup aws
  TEMP_HOME=$(mktemp -d)

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

It 'attempts recovery when auth directory is missing'
When run bash -c 'env HOME="'"$TEMP_HOME"'" OBJECTSTORE_ACCESS_KEY=key OBJECTSTORE_SECRET_KEY=secret OBJECTSTORE_ENDPOINT=https://example.com bash '"$SCRIPT"' 2>&1; cat "$MOCK_LOG"'
The status should be success
The output should include 'Auth files missing'
The output should include 's3 sync'
End

It 'skips recovery when auth files exist'
mkdir -p "$TEMP_HOME/.cli-proxy-api/objectstore/auths"
touch "$TEMP_HOME/.cli-proxy-api/objectstore/auths/existing.json"
When run bash -c 'env HOME="'"$TEMP_HOME"'" OBJECTSTORE_ACCESS_KEY=key OBJECTSTORE_SECRET_KEY=secret OBJECTSTORE_ENDPOINT=https://example.com bash '"$SCRIPT"' 2>&1; cat "$MOCK_LOG" 2>/dev/null || true'
The status should be success
The output should eq ''
End
End

Describe 'backup-and-recover.sh'
SCRIPT="$SCRIPTS_DIR/backup-and-recover.sh"

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

It 'sources .env and runs backup and recovery scripts'
When run bash -c 'env HOME="'"$TEMP_HOME"'" bash '"$SCRIPT"' 2>&1'
The status should be success
The output should include 'Starting backup'
The output should include 'Checking for recovery'
The output should include 'Backup/recovery cycle complete'
End
End

End
