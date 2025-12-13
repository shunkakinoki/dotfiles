#!/usr/bin/env bash
# shellcheck disable=SC2329

Describe 'notify.sh'
SCRIPT="$PWD/config/claude/notify.sh"

Describe 'when Pushover is configured'
setup() {
  export PUSHOVER_API_TOKEN="test_token"
  export PUSHOVER_USER_KEY="test_user"
}
Before 'setup'

It 'exits early and skips local notification'
When run bash -c 'echo "{\"message\": \"Test message\"}" | bash '"$SCRIPT"
The status should be success
The output should eq ''
End
End

Describe 'Pushover configured with .env present'
setup() {
  mock_bin_setup osascript
  TEMP_HOME=$(mktemp -d)
  mkdir -p "$TEMP_HOME/dotfiles"
  cat >"$TEMP_HOME/dotfiles/.env" <<'ENV'
touch "$HOME/notify_sourced_marker"
PUSHOVER_API_TOKEN=bad_token
PUSHOVER_USER_KEY=bad_user
ENV
}
cleanup() {
  rm -rf "$TEMP_HOME"
  mock_bin_cleanup
}
Before 'setup'
After 'cleanup'

It 'does not source HOME/dotfiles/.env when credentials already set'
When run bash -c 'echo "{\"message\": \"Test message\"}" | env HOME="'"$TEMP_HOME"'" PUSHOVER_API_TOKEN="test_token" PUSHOVER_USER_KEY="test_user" bash '"$SCRIPT"'; test ! -f "'"$TEMP_HOME"'/notify_sourced_marker"; cat "$MOCK_LOG"'
The status should be success
The output should eq ''
End
End

Describe 'Notification hook (no Pushover)'
setup() {
  mock_bin_setup osascript

  # Unset Pushover credentials to ensure clean test environment
  unset PUSHOVER_API_TOKEN
  unset PUSHOVER_USER_KEY
}
cleanup() {
  mock_bin_cleanup
}
Before 'setup'
After 'cleanup'

It 'exits 0 for login notification'
# Use fake HOME so script cannot source real .env file
When run bash -c 'echo "{\"message\": \"Claude Code login successful\"}" | env HOME=/nonexistent bash '"$SCRIPT"
The status should be success
End

It 'exits 0 for waiting notification'
# Use fake HOME so script cannot source real .env file
When run bash -c 'echo "{\"message\": \"Claude is waiting for your input\"}" | env HOME=/nonexistent bash '"$SCRIPT"
The status should be success
End

It 'sends Basso notification for permission request'
When run bash -c 'echo "{\"message\": \"Claude needs your permission to use Bash\"}" | env HOME=/nonexistent bash '"$SCRIPT"'; cat "$MOCK_LOG"'
The status should be success
The output should include 'Bash permission required'
The output should include 'sound name "Basso"'
End
End

Describe 'when credentials come from HOME/dotfiles/.env'
setup() {
  mock_bin_setup osascript
  TEMP_HOME=$(mktemp -d)
  mkdir -p "$TEMP_HOME/dotfiles"
  cat >"$TEMP_HOME/dotfiles/.env" <<'ENV'
PUSHOVER_API_TOKEN=test_token
PUSHOVER_USER_KEY=test_user
ENV

  unset PUSHOVER_API_TOKEN
  unset PUSHOVER_USER_KEY
}
cleanup() {
  rm -rf "$TEMP_HOME"
  mock_bin_cleanup
}
Before 'setup'
After 'cleanup'

It 'exits early and does not send local notification'
When run bash -c 'echo "{\"message\": \"Test message\"}" | env HOME="'"$TEMP_HOME"'" bash '"$SCRIPT"'; cat "$MOCK_LOG"'
The status should be success
The output should eq ''
End
End

Describe 'credential sourcing edge cases'
setup() {
  mock_bin_setup osascript
  TEMP_HOME=$(mktemp -d)
  mkdir -p "$TEMP_HOME/dotfiles"

  unset PUSHOVER_API_TOKEN
  unset PUSHOVER_USER_KEY
}
cleanup() {
  rm -rf "$TEMP_HOME"
  mock_bin_cleanup
}
Before 'setup'
After 'cleanup'

It 'sources .env when only one credential is set'
cat >"$TEMP_HOME/dotfiles/.env" <<'ENV'
PUSHOVER_USER_KEY=from_env
ENV
When run bash -c 'echo "{\"message\": \"Test message\"}" | env HOME="'"$TEMP_HOME"'" PUSHOVER_API_TOKEN="present" bash '"$SCRIPT"'; cat "$MOCK_LOG"'
The status should be success
The output should eq ''
End

It 'sends local notification when .env is incomplete'
cat >"$TEMP_HOME/dotfiles/.env" <<'ENV'
PUSHOVER_API_TOKEN=only_token
ENV
When run bash -c 'echo "{\"message\": \"Hello\"}" | env HOME="'"$TEMP_HOME"'" bash '"$SCRIPT"'; cat "$MOCK_LOG"'
The status should be success
The output should include 'display notification'
End

It 'ignores .env stderr and still sends local notification on source error'
cat >"$TEMP_HOME/dotfiles/.env" <<'ENV'
this is not valid bash
ENV
When run bash -c 'echo "{\"message\": \"Hello\"}" | env HOME="'"$TEMP_HOME"'" bash '"$SCRIPT"'; cat "$MOCK_LOG"'
The status should be success
The output should include 'display notification'
End
End

Describe 'SessionEnd hook (no Pushover)'
setup() {
  mock_bin_setup osascript

  # Unset Pushover credentials to ensure clean test environment
  unset PUSHOVER_API_TOKEN
  unset PUSHOVER_USER_KEY
}
cleanup() {
  mock_bin_cleanup
}
Before 'setup'
After 'cleanup'

It 'exits 0 for session end'
# Use fake HOME so script cannot source real .env file
When run bash -c 'echo "{\"reason\": \"user_exit\"}" | env HOME=/nonexistent bash '"$SCRIPT"
The status should be success
End
End

Describe 'other hooks (no Pushover)'
setup() {
  mock_bin_setup osascript
  TEMP_HOME=$(mktemp -d)

  unset PUSHOVER_API_TOKEN
  unset PUSHOVER_USER_KEY
}
cleanup() {
  rm -rf "$TEMP_HOME"
  mock_bin_cleanup
}
Before 'setup'
After 'cleanup'

It 'notifies on PreCompact auto trigger'
When run bash -c 'echo "{\"trigger\": \"auto\"}" | env HOME=/nonexistent bash '"$SCRIPT"'; cat "$MOCK_LOG"'
The status should be success
The output should include 'Auto-compacting context'
End

It 'notifies on SubagentStop'
When run bash -c 'echo "{\"stop_hook_active\": true}" | env HOME=/nonexistent bash '"$SCRIPT"'; cat "$MOCK_LOG"'
The status should be success
The output should include 'Subagent task completed'
End

It 'notifies on Stop with cwd and session id'
When run bash -c 'echo "{\"cwd\": \"'"$TEMP_HOME"'/work\", \"session_id\": \"abcdef0123456789\"}" | env HOME="'"$TEMP_HOME"'" bash '"$SCRIPT"'; cat "$MOCK_LOG"'
The status should be success
The output should include 'Work completed in ~/work (abcdef01)'
End

It 'warns on risky PreToolUse Bash command'
When run bash -c 'echo "{\"tool\": {\"name\": \"Bash\", \"input\": \"rm -rf /\"}}" | env HOME=/nonexistent bash '"$SCRIPT"'; cat "$MOCK_LOG"'
The status should be success
The output should include 'Risky: rm -rf /'
The output should include 'sound name "Basso"'
End

It 'does not warn on PreToolUse non-Bash tool'
When run bash -c 'echo "{\"tool\": {\"name\": \"Read\", \"input\": {}}}" | env HOME=/nonexistent bash '"$SCRIPT"'; cat "$MOCK_LOG"'
The status should be success
The output should eq ''
End
End
End
