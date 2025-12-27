#!/usr/bin/env bash
# shellcheck disable=SC2329,SC2016

Describe 'cliproxyapi backup scripts'
SCRIPTS_DIR="$PWD/home-manager/services/cliproxyapi/scripts"

Describe 'backup-auth.sh'

setup() {
  mock_bin_setup aws rsync
  TEMP_HOME=$(mktemp -d)
  mkdir -p "$TEMP_HOME/.cli-proxy-api/objectstore/auths"
  # Preprocess script to replace @aws@ and @rsync@ placeholders
  SCRIPT=$(nix_script_preprocess "$SCRIPTS_DIR/backup-auth.sh")

  # Unset objectstore credentials to ensure clean test environment
  unset OBJECTSTORE_ACCESS_KEY
  unset OBJECTSTORE_SECRET_KEY
  unset OBJECTSTORE_ENDPOINT
}

cleanup() {
  rm -rf "$TEMP_HOME"
  mock_bin_cleanup
  nix_script_cleanup
}

Before 'setup'
After 'cleanup'

It 'pulls from R2 but skips push when auth directory is empty'
When run bash -c 'env HOME="'"$TEMP_HOME"'" OBJECTSTORE_ACCESS_KEY=key OBJECTSTORE_SECRET_KEY=secret OBJECTSTORE_ENDPOINT=https://example.com bash '"$SCRIPT"' 2>&1; cat "$MOCK_LOG" 2>/dev/null || true'
The status should be success
# Should pull from R2 auths/ and backup/auths/
The output should include 's3://cliproxyapi/auths/'
The output should include 's3://cliproxyapi/backup/auths/'
# Should NOT push to R2 since local is empty after pull
The output should not include 'Syncing auth files to R2'
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

setup() {
  mock_bin_setup aws
  TEMP_HOME=$(mktemp -d)
  # Preprocess script to replace @aws@ placeholder
  SCRIPT=$(nix_script_preprocess "$SCRIPTS_DIR/recover-auth.sh")

  unset OBJECTSTORE_ACCESS_KEY
  unset OBJECTSTORE_SECRET_KEY
  unset OBJECTSTORE_ENDPOINT
}

cleanup() {
  rm -rf "$TEMP_HOME"
  mock_bin_cleanup
  nix_script_cleanup
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

setup() {
  mock_bin_setup aws rsync
  TEMP_HOME=$(mktemp -d)
  mkdir -p "$TEMP_HOME/.cli-proxy-api/objectstore/auths"
  mkdir -p "$TEMP_HOME/dotfiles"

  # Preprocess script with its dependencies
  SCRIPT=$(nix_script_preprocess_with_deps "$SCRIPTS_DIR/backup-and-recover.sh" backup-auth.sh recover-auth.sh)

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
  nix_script_cleanup
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
