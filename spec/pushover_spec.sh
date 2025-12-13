#!/usr/bin/env bash
# shellcheck disable=SC2329

Describe 'pushover.sh'
SCRIPT="$PWD/config/claude/pushover.sh"

Describe 'credential handling'
setup() {
  # Create a mock curl in case credentials leak through
  MOCK_BIN=$(mktemp -d)
  printf '#!/bin/sh\nexit 0\n' >"$MOCK_BIN/curl"
  chmod +x "$MOCK_BIN/curl"
  export PATH="$MOCK_BIN:$PATH"

  # Unset credentials to ensure clean test environment
  unset PUSHOVER_API_TOKEN
  unset PUSHOVER_USER_KEY
}
cleanup() {
  rm -rf "$MOCK_BIN"
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
  # Create a mock curl that does nothing
  MOCK_BIN=$(mktemp -d)
  printf '#!/bin/sh\nexit 0\n' >"$MOCK_BIN/curl"
  chmod +x "$MOCK_BIN/curl"
  export PATH="$MOCK_BIN:$PATH"

  # Set test credentials
  export PUSHOVER_API_TOKEN="test_token"
  export PUSHOVER_USER_KEY="test_user"
}
cleanup() {
  rm -rf "$MOCK_BIN"
}
Before 'setup'
After 'cleanup'

It 'skips notification for "other" reason'
When run bash -c 'echo "{\"reason\": \"other\"}" | bash '"$SCRIPT"
The status should be success
The output should eq ''
End

It 'processes notification for "user_exit" reason'
When run bash -c 'echo "{\"reason\": \"user_exit\"}" | bash '"$SCRIPT"
The status should be success
End
End

Describe 'Notification hook'
setup() {
  # Create a mock curl that does nothing
  MOCK_BIN=$(mktemp -d)
  printf '#!/bin/sh\nexit 0\n' >"$MOCK_BIN/curl"
  chmod +x "$MOCK_BIN/curl"
  export PATH="$MOCK_BIN:$PATH"

  # Set test credentials
  export PUSHOVER_API_TOKEN="test_token"
  export PUSHOVER_USER_KEY="test_user"
}
cleanup() {
  rm -rf "$MOCK_BIN"
}
Before 'setup'
After 'cleanup'

It 'skips login notification'
When run bash -c 'echo "{\"message\": \"Claude Code login successful\"}" | bash '"$SCRIPT"
The status should be success
End

It 'processes waiting notification'
When run bash -c 'echo "{\"message\": \"Claude is waiting for your input\"}" | bash '"$SCRIPT"
The status should be success
End
End
End
