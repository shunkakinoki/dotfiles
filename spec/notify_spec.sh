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
When run bash "$SCRIPT" <<<'{"message": "Test message"}'
The status should be success
The output should eq ''
End
End

Describe 'Notification hook (no Pushover)'
setup() {
  unset PUSHOVER_API_TOKEN 2>/dev/null || true
  unset PUSHOVER_USER_KEY 2>/dev/null || true
}
Before 'setup'

It 'exits 0 for login notification'
When run bash "$SCRIPT" <<<'{"message": "Claude Code login successful"}'
The status should be success
End

It 'exits 0 for waiting notification'
When run bash "$SCRIPT" <<<'{"message": "Claude is waiting for your input"}'
The status should be success
End
End

Describe 'SessionEnd hook (no Pushover)'
setup() {
  unset PUSHOVER_API_TOKEN 2>/dev/null || true
  unset PUSHOVER_USER_KEY 2>/dev/null || true
}
Before 'setup'

It 'exits 0 for session end'
When run bash "$SCRIPT" <<<'{"reason": "user_exit"}'
The status should be success
End
End
End
