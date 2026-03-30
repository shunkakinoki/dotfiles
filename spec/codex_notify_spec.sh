#!/usr/bin/env bash
# shellcheck disable=SC2329,SC2016

Describe 'codex hooks/notify.sh'
SCRIPT="$PWD/config/codex/hooks/notify.sh"

Describe 'SessionStart event'
setup() {
  mock_bin_setup notify-local
  unset PUSHOVER_API_TOKEN
  unset PUSHOVER_USER_KEY
}
cleanup() {
  mock_bin_cleanup
}
Before 'setup'
After 'cleanup'

It 'notifies on startup'
When run bash -c 'echo "{\"hook_event_name\": \"SessionStart\", \"source\": \"startup\", \"cwd\": \"/tmp\"}" | env HOME=/nonexistent bash '"$SCRIPT"'; cat "$MOCK_LOG"'
The status should be success
The output should include 'Session started'
End

It 'notifies on resume'
When run bash -c 'echo "{\"hook_event_name\": \"SessionStart\", \"source\": \"resume\", \"cwd\": \"/tmp\"}" | env HOME=/nonexistent bash '"$SCRIPT"'; cat "$MOCK_LOG"'
The status should be success
The output should include 'Session resumed'
End
End

Describe 'Stop event'
setup() {
  mock_bin_setup notify-local
  unset PUSHOVER_API_TOKEN
  unset PUSHOVER_USER_KEY
}
cleanup() {
  mock_bin_cleanup
}
Before 'setup'
After 'cleanup'

It 'notifies work completed'
When run bash -c 'echo "{\"hook_event_name\": \"Stop\", \"last_assistant_message\": \"Done\", \"cwd\": \"/tmp\"}" | env HOME=/nonexistent bash '"$SCRIPT"'; cat "$MOCK_LOG"'
The status should be success
The output should include 'Work completed'
End
End

Describe 'skips when Pushover configured'
It 'exits silently'
When run bash -c 'echo "{\"hook_event_name\": \"Stop\", \"cwd\": \"/tmp\"}" | env HOME=/nonexistent PUSHOVER_API_TOKEN=tok PUSHOVER_USER_KEY=usr bash '"$SCRIPT"
The status should be success
The output should eq ''
End
End
End
