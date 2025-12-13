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
End
End
