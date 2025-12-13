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
  # Create mock osascript that does nothing
  MOCK_BIN=$(mktemp -d)
  printf '#!/bin/sh\nexit 0\n' >"$MOCK_BIN/osascript"
  chmod +x "$MOCK_BIN/osascript"
  export PATH="$MOCK_BIN:$PATH"

  # Unset Pushover credentials to ensure clean test environment
  unset PUSHOVER_API_TOKEN
  unset PUSHOVER_USER_KEY
}
cleanup() {
  rm -rf "$MOCK_BIN"
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
End

Describe 'SessionEnd hook (no Pushover)'
setup() {
  # Create mock osascript that does nothing
  MOCK_BIN=$(mktemp -d)
  printf '#!/bin/sh\nexit 0\n' >"$MOCK_BIN/osascript"
  chmod +x "$MOCK_BIN/osascript"
  export PATH="$MOCK_BIN:$PATH"

  # Unset Pushover credentials to ensure clean test environment
  unset PUSHOVER_API_TOKEN
  unset PUSHOVER_USER_KEY
}
cleanup() {
  rm -rf "$MOCK_BIN"
}
Before 'setup'
After 'cleanup'

It 'exits 0 for session end'
# Use fake HOME so script cannot source real .env file
When run bash -c 'echo "{\"reason\": \"user_exit\"}" | env HOME=/nonexistent bash '"$SCRIPT"
The status should be success
End
End
End
