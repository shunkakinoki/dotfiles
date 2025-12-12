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
}
cleanup() {
  rm -rf "$MOCK_BIN"
}
Before 'setup'
After 'cleanup'

It 'exits 0 when no credentials are set'
# Use fake HOME and unset env vars so script cannot find credentials
When run bash -c "unset PUSHOVER_API_TOKEN PUSHOVER_USER_KEY; HOME=/nonexistent bash '$SCRIPT'" <<<'{}'
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
}
cleanup() {
  rm -rf "$MOCK_BIN"
}
Before 'setup'
After 'cleanup'

It 'skips notification for "other" reason'
# Clear any inherited credentials, set test ones
When run bash -c "unset PUSHOVER_API_TOKEN PUSHOVER_USER_KEY; export PUSHOVER_API_TOKEN=test_token PUSHOVER_USER_KEY=test_user; bash '$SCRIPT'" <<<'{"reason": "other"}'
The status should be success
The output should eq ''
End

It 'processes notification for "user_exit" reason'
When run bash -c "unset PUSHOVER_API_TOKEN PUSHOVER_USER_KEY; export PUSHOVER_API_TOKEN=test_token PUSHOVER_USER_KEY=test_user; bash '$SCRIPT'" <<<'{"reason": "user_exit"}'
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
}
cleanup() {
  rm -rf "$MOCK_BIN"
}
Before 'setup'
After 'cleanup'

It 'skips login notification'
When run bash -c "unset PUSHOVER_API_TOKEN PUSHOVER_USER_KEY; export PUSHOVER_API_TOKEN=test_token PUSHOVER_USER_KEY=test_user; bash '$SCRIPT'" <<<'{"message": "Claude Code login successful"}'
The status should be success
End

It 'processes waiting notification'
When run bash -c "unset PUSHOVER_API_TOKEN PUSHOVER_USER_KEY; export PUSHOVER_API_TOKEN=test_token PUSHOVER_USER_KEY=test_user; bash '$SCRIPT'" <<<'{"message": "Claude is waiting for your input"}'
The status should be success
End
End
End
