#!/usr/bin/env bash
# shellcheck disable=SC2329,SC2016

Describe 'cliproxyapi backup scripts'
SCRIPTS_DIR="$PWD/home-manager/services/cliproxyapi/scripts"

# Preprocess scripts once at describe-time
__PREPROCESSED_DIR=$(mktemp -d)
__HYDRATE_SCRIPT="$__PREPROCESSED_DIR/hydrate.sh"
__BACKUP_SCRIPT="$__PREPROCESSED_DIR/backup.sh"

# Preprocess hydrate.sh
sed \
  -e 's|@aws@|aws|g' \
  "$SCRIPTS_DIR/hydrate.sh" >"$__HYDRATE_SCRIPT"
chmod +x "$__HYDRATE_SCRIPT"

# Preprocess backup.sh
sed \
  -e 's|@aws@|aws|g' \
  "$SCRIPTS_DIR/backup.sh" >"$__BACKUP_SCRIPT"
chmod +x "$__BACKUP_SCRIPT"

Describe 'hydrate.sh'

setup() {
  mock_bin_setup aws
  TEMP_HOME=$(mktemp -d)
  mkdir -p "$TEMP_HOME/.cli-proxy-api/objectstore/auths"
  mkdir -p "$TEMP_HOME/.ccs/cliproxy/auth"
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

It 'pulls from S3 auths and backup/auths'
When run bash -c 'HOME="'"$TEMP_HOME"'" bash "'"$__HYDRATE_SCRIPT"'" 2>&1; cat "$MOCK_LOG" 2>/dev/null || true'
The status should be success
The output should include 's3://cliproxyapi/auths/'
The output should include 's3://cliproxyapi/backup/auths/'
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
  TEMP_HOME=$(mktemp -d)
  mkdir -p "$TEMP_HOME/.cli-proxy-api/objectstore/auths"
  mkdir -p "$TEMP_HOME/.ccs/cliproxy/auth"
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

It 'skips when auth directory is empty'
When run bash -c 'HOME="'"$TEMP_HOME"'" bash "'"$__BACKUP_SCRIPT"'" 2>&1'
The status should be success
The output should include 'No auth files to backup'
End

It 'pushes to S3 when auth files exist'
touch "$TEMP_HOME/.cli-proxy-api/objectstore/auths/test-auth.json"
When run bash -c 'HOME="'"$TEMP_HOME"'" bash "'"$__BACKUP_SCRIPT"'" 2>&1; cat "$MOCK_LOG" 2>/dev/null || true'
The status should be success
The output should include 's3://cliproxyapi/auths/'
The output should include 's3://cliproxyapi/backup/auths/'
End

It 'skips when credentials are missing'
rm -f "$TEMP_HOME/dotfiles/.env"
touch "$TEMP_HOME/.cli-proxy-api/objectstore/auths/test-auth.json"
When run bash -c 'HOME="'"$TEMP_HOME"'" bash "'"$__BACKUP_SCRIPT"'" 2>&1'
The status should be success
The output should include 'Missing S3 credentials'
End
End

# Cleanup preprocessed scripts at end
cleanup_preprocessed() {
  rm -rf "$__PREPROCESSED_DIR"
}
AfterAll 'cleanup_preprocessed'

End
