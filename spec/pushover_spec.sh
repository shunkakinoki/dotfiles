#!/usr/bin/env bash
# shellcheck disable=SC2329

Describe 'pushover.sh'
SCRIPT="$PWD/config/claude/pushover.sh"

Describe 'credential handling'
setup() {
  mock_bin_setup curl

  # Unset credentials to ensure clean test environment
  unset PUSHOVER_API_TOKEN
  unset PUSHOVER_USER_KEY
}
cleanup() {
  mock_bin_cleanup
}
Before 'setup'
After 'cleanup'

It 'exits 0 when no credentials are set'
# Use fake HOME so script cannot find credentials
When run bash -c 'echo "{}" | env HOME=/nonexistent bash '"$SCRIPT"
The status should be success
The output should eq ''
End
End

Describe 'SessionEnd hook'
setup() {
  mock_bin_setup curl

  # Set test credentials
  export PUSHOVER_API_TOKEN="test_token"
  export PUSHOVER_USER_KEY="test_user"
}
cleanup() {
  mock_bin_cleanup
}
Before 'setup'
After 'cleanup'

It 'skips notification for "other" reason'
When run bash -c 'echo "{\"reason\": \"other\"}" | bash '"$SCRIPT"'; cat "$MOCK_LOG"'
The status should be success
The output should eq ''
End

It 'processes notification for "user_exit" reason'
When run bash -c 'echo "{\"reason\": \"user_exit\"}" | bash '"$SCRIPT"'; cat "$MOCK_LOG"'
The status should be success
The output should include 'priority=0'
The output should include 'https://api.pushover.net/1/messages.json'
End
End

Describe 'Notification hook'
setup() {
  mock_bin_setup curl

  # Set test credentials
  export PUSHOVER_API_TOKEN="test_token"
  export PUSHOVER_USER_KEY="test_user"

  TRANSCRIPT=$(mktemp)
}
cleanup() {
  rm -f "$TRANSCRIPT"
  mock_bin_cleanup
}
Before 'setup'
After 'cleanup'

It 'skips login notification'
When run bash -c 'echo "{\"message\": \"Claude Code login successful\"}" | bash '"$SCRIPT"'; cat "$MOCK_LOG"'
The status should be success
The output should eq ''
End

It 'processes waiting notification'
When run bash -c 'echo "{\"message\": \"Claude is waiting for your input\", \"cwd\": \"/tmp\"}" | bash '"$SCRIPT"'; cat "$MOCK_LOG"'
The status should be success
The output should include 'priority=1'
The output should include 'Waiting'
End

It 'processes permission notification at high priority'
When run bash -c 'echo "{\"message\": \"Claude needs your permission to use Bash\", \"cwd\": \"/tmp\"}" | bash '"$SCRIPT"'; cat "$MOCK_LOG"'
The status should be success
The output should include 'priority=1'
The output should include 'Permission required'
End

It 'includes transcript stats when transcript_path is present'
cat >"$TRANSCRIPT" <<'JSON'
{"type":"user","message":{"content":[{"type":"text","text":"Fix tests"}]}}
{"cwd":"/tmp/project"}
{"type":"tool_use","tool_use":{"name":"Bash","input":{"command":"echo ok"}}}
{"type":"tool_use","tool_use":{"name":"Write","input":{"file_path":"spec/foo_spec.sh"}}}
JSON
When run bash -c 'echo "{\"message\": \"Claude is waiting for your input\", \"transcript_path\": \"'"$TRANSCRIPT"'\"}" | bash '"$SCRIPT"'; cat "$MOCK_LOG"'
The status should be success
The output should include 'tools,'
The output should include 'files'
End
End

Describe 'Stop hook'
setup() {
  mock_bin_setup curl

  export PUSHOVER_API_TOKEN="test_token"
  export PUSHOVER_USER_KEY="test_user"

  TRANSCRIPT=$(mktemp)
}
cleanup() {
  rm -f "$TRANSCRIPT"
  mock_bin_cleanup
}
Before 'setup'
After 'cleanup'

It 'notifies plan ready for approval (plan mode + ExitPlanMode + no files)'
cat >"$TRANSCRIPT" <<'JSON'
{"type":"user","message":{"content":[{"type":"text","text":"Do the thing"}]}}
{"cwd":"/tmp/project"}
{"type":"assistant","message":{"content":[{"type":"tool_use","name":"ExitPlanMode"}]}}
JSON
When run bash -c 'echo "{\"hook_event_name\": \"Stop\", \"transcript_path\": \"'"$TRANSCRIPT"'\", \"permission_mode\": \"plan\"}" | bash '"$SCRIPT"'; cat "$MOCK_LOG"'
The status should be success
The output should include 'Plan ready for approval'
The output should include 'priority=1'
End

It 'notifies work completed when files were modified'
cat >"$TRANSCRIPT" <<'JSON'
{"type":"user","message":{"content":[{"type":"text","text":"Update config"}]}}
{"cwd":"/tmp/project"}
{"type":"tool_use","tool_use":{"name":"Write","input":{"file_path":"config/foo"}}}
{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Bash"}]}}
JSON
When run bash -c 'echo "{\"hook_event_name\": \"Stop\", \"transcript_path\": \"'"$TRANSCRIPT"'\", \"permission_mode\": \"plan\"}" | bash '"$SCRIPT"'; cat "$MOCK_LOG"'
The status should be success
The output should include 'Work completed'
The output should include 'priority=0'
End
End
End
