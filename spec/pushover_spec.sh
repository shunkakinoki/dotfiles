#!/usr/bin/env bash
# shellcheck disable=SC2329

Describe 'pushover.sh'
SCRIPT="$PWD/config/claude/pushover.sh"

Describe 'credential handling'
It 'exits 0 when no credentials are set'
unset PUSHOVER_API_TOKEN 2>/dev/null || true
unset PUSHOVER_USER_KEY 2>/dev/null || true
When run bash "$SCRIPT" <<<'{}'
The status should be success
The output should eq ''
End
End

Describe 'SessionEnd hook'
setup() {
  export PUSHOVER_API_TOKEN="test_token"
  export PUSHOVER_USER_KEY="test_user"
}
Before 'setup'

mock_curl() {
  echo "CURL_CALLED"
}

It 'skips notification for "other" reason'
When run bash "$SCRIPT" <<<'{"reason": "other"}'
The status should be success
The output should eq ''
End

It 'processes notification for "user_exit" reason'
When run bash "$SCRIPT" <<<'{"reason": "user_exit"}'
The status should be success
End
End

Describe 'Notification hook'
setup() {
  export PUSHOVER_API_TOKEN="test_token"
  export PUSHOVER_USER_KEY="test_user"
}
Before 'setup'

It 'skips login notification'
When run bash "$SCRIPT" <<<'{"message": "Claude Code login successful"}'
The status should be success
End

It 'processes waiting notification'
When run bash "$SCRIPT" <<<'{"message": "Claude is waiting for your input"}'
The status should be success
End
End
End
