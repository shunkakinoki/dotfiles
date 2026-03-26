#!/usr/bin/env bash
# shellcheck disable=SC2329,SC2016

Describe 'cliproxyapi keychain-sync'
SCRIPTS_DIR="$PWD/home-manager/services/cliproxyapi/scripts"

# Preprocess script once at describe-time
__PREPROCESSED_DIR=$(mktemp -d)
__KEYCHAIN_SYNC_SCRIPT="$__PREPROCESSED_DIR/keychain-sync.sh"

sed \
  -e 's|@email@|test@example.com|g' \
  -e 's|@keychain_account@|testuser|g' \
  -e 's|@jq@|jq|g' \
  "$SCRIPTS_DIR/keychain-sync.sh" >"$__KEYCHAIN_SYNC_SCRIPT"
chmod +x "$__KEYCHAIN_SYNC_SCRIPT"

Describe 'sync_claude'

setup() {
  TEMP_HOME=$(mktemp -d)
  mkdir -p "$TEMP_HOME/.cli-proxy-api/objectstore/auths"

  # Create a mock security binary that prints contents of $HOME/.mock-keychain-data
  MOCK_SECURITY="$__PREPROCESSED_DIR/mock-security"
  cat >"$MOCK_SECURITY" <<'SCRIPT'
#!/usr/bin/env bash
if [ -f "$HOME/.mock-keychain-data" ]; then
  cat "$HOME/.mock-keychain-data"
else
  exit 44
fi
SCRIPT
  chmod +x "$MOCK_SECURITY"
}

cleanup() {
  rm -f "$TEMP_HOME/.mock-keychain-data" 2>/dev/null || true
  rmdir "$TEMP_HOME/.cli-proxy-api/objectstore/auths" "$TEMP_HOME/.cli-proxy-api/objectstore" "$TEMP_HOME/.cli-proxy-api" "$TEMP_HOME/.codex" "$TEMP_HOME" 2>/dev/null || true
}

Before 'setup'
After 'cleanup'

It 'writes claude auth file when keychain has valid data'
cat >"$TEMP_HOME/.mock-keychain-data" <<'JSON'
{"claudeAiOauth":{"accessToken":"sk-ant-test-token","refreshToken":"sk-ant-test-refresh","expiresAt":1900000000000}}
JSON
When run bash -c 'HOME="'"$TEMP_HOME"'" SECURITY="'"$MOCK_SECURITY"'" bash "'"$__KEYCHAIN_SYNC_SCRIPT"'" 2>&1'
The status should be success
The output should include 'Claude: synced new token'
End

It 'produces valid cliproxyapi auth format'
cat >"$TEMP_HOME/.mock-keychain-data" <<'JSON'
{"claudeAiOauth":{"accessToken":"sk-ant-test-token","refreshToken":"sk-ant-test-refresh","expiresAt":1900000000000}}
JSON
When run bash -c 'HOME="'"$TEMP_HOME"'" SECURITY="'"$MOCK_SECURITY"'" bash "'"$__KEYCHAIN_SYNC_SCRIPT"'" 2>/dev/null && jq -r ".type" "'"$TEMP_HOME"'/.cli-proxy-api/objectstore/auths/claude-test@example.com.json"'
The status should be success
The output should equal 'claude'
End

It 'skips when keychain entry is empty'
printf '' >"$TEMP_HOME/.mock-keychain-data"
When run bash -c 'HOME="'"$TEMP_HOME"'" SECURITY="'"$MOCK_SECURITY"'" bash "'"$__KEYCHAIN_SYNC_SCRIPT"'" 2>&1'
The status should be success
The output should include 'keychain entry empty'
End

It 'skips when keychain is unavailable'
rm -f "$TEMP_HOME/.mock-keychain-data"
When run bash -c 'HOME="'"$TEMP_HOME"'" SECURITY="'"$MOCK_SECURITY"'" bash "'"$__KEYCHAIN_SYNC_SCRIPT"'" 2>&1'
The status should be success
The output should not include 'Claude: synced'
End

It 'skips when access token is missing'
cat >"$TEMP_HOME/.mock-keychain-data" <<'JSON'
{"claudeAiOauth":{"refreshToken":"sk-ant-test-refresh"}}
JSON
When run bash -c 'HOME="'"$TEMP_HOME"'" SECURITY="'"$MOCK_SECURITY"'" bash "'"$__KEYCHAIN_SYNC_SCRIPT"'" 2>&1'
The status should be success
The output should include 'no access_token'
End

It 'does not overwrite when token is unchanged'
cat >"$TEMP_HOME/.mock-keychain-data" <<'JSON'
{"claudeAiOauth":{"accessToken":"sk-ant-same-token","refreshToken":"sk-ant-test-refresh","expiresAt":1900000000000}}
JSON
printf '{"access_token":"sk-ant-same-token"}' >"$TEMP_HOME/.cli-proxy-api/objectstore/auths/claude-test@example.com.json"
When run bash -c 'HOME="'"$TEMP_HOME"'" SECURITY="'"$MOCK_SECURITY"'" bash "'"$__KEYCHAIN_SYNC_SCRIPT"'" 2>&1'
The status should be success
The output should not include 'synced new token'
End

End

Describe 'sync_codex'

setup() {
  TEMP_HOME=$(mktemp -d)
  mkdir -p "$TEMP_HOME/.cli-proxy-api/objectstore/auths"
  mkdir -p "$TEMP_HOME/.codex"

  # Mock security that always fails (no keychain)
  MOCK_SECURITY_FAIL="$__PREPROCESSED_DIR/mock-security-fail"
  cat >"$MOCK_SECURITY_FAIL" <<'SCRIPT'
#!/usr/bin/env bash
exit 44
SCRIPT
  chmod +x "$MOCK_SECURITY_FAIL"
}

cleanup() {
  rm -f "$TEMP_HOME/.codex/auth.json" 2>/dev/null || true
  rmdir "$TEMP_HOME/.cli-proxy-api/objectstore/auths" "$TEMP_HOME/.cli-proxy-api/objectstore" "$TEMP_HOME/.cli-proxy-api" "$TEMP_HOME/.codex" "$TEMP_HOME" 2>/dev/null || true
}

Before 'setup'
After 'cleanup'

It 'writes codex auth file from ~/.codex/auth.json'
cat >"$TEMP_HOME/.codex/auth.json" <<'JSON'
{"auth_mode":"chatgpt","OPENAI_API_KEY":"sk-test-key","tokens":{"access_token":"test-codex-token","refresh_token":"test-refresh","account_id":"acct-123"},"last_refresh":"2026-01-01T00:00:00Z"}
JSON
When run bash -c 'HOME="'"$TEMP_HOME"'" SECURITY="'"$MOCK_SECURITY_FAIL"'" bash "'"$__KEYCHAIN_SYNC_SCRIPT"'" 2>&1'
The status should be success
The output should include 'Codex: synced new token'
End

It 'produces valid cliproxyapi auth format'
cat >"$TEMP_HOME/.codex/auth.json" <<'JSON'
{"auth_mode":"chatgpt","tokens":{"access_token":"test-codex-token","refresh_token":"test-refresh","account_id":"acct-123"},"last_refresh":"2026-01-01T00:00:00Z"}
JSON
When run bash -c 'HOME="'"$TEMP_HOME"'" SECURITY="'"$MOCK_SECURITY_FAIL"'" bash "'"$__KEYCHAIN_SYNC_SCRIPT"'" 2>/dev/null && jq -r ".type" "'"$TEMP_HOME"'/.cli-proxy-api/objectstore/auths/codex-test@example.com.json"'
The status should be success
The output should equal 'codex'
End

It 'skips when codex auth file is missing'
rm -f "$TEMP_HOME/.codex/auth.json"
When run bash -c 'HOME="'"$TEMP_HOME"'" SECURITY="'"$MOCK_SECURITY_FAIL"'" bash "'"$__KEYCHAIN_SYNC_SCRIPT"'" 2>&1'
The status should be success
The output should not include 'Codex: synced'
End

It 'does not overwrite when token is unchanged'
cat >"$TEMP_HOME/.codex/auth.json" <<'JSON'
{"tokens":{"access_token":"same-token","refresh_token":"test-refresh"},"last_refresh":"2026-01-01T00:00:00Z"}
JSON
printf '{"access_token":"same-token"}' >"$TEMP_HOME/.cli-proxy-api/objectstore/auths/codex-test@example.com.json"
When run bash -c 'HOME="'"$TEMP_HOME"'" SECURITY="'"$MOCK_SECURITY_FAIL"'" bash "'"$__KEYCHAIN_SYNC_SCRIPT"'" 2>&1'
The status should be success
The output should not include 'synced new token'
End

End

# Cleanup preprocessed scripts at end
cleanup_preprocessed() {
  rm -f "$__PREPROCESSED_DIR"/*.sh "$__PREPROCESSED_DIR"/*.sh.bak "$__PREPROCESSED_DIR"/mock-security* 2>/dev/null || true
  rmdir "$__PREPROCESSED_DIR" 2>/dev/null || true
}
AfterAll 'cleanup_preprocessed'

End
