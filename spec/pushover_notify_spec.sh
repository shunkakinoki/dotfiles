#!/usr/bin/env bash
# shellcheck disable=SC2329

Describe 'pushover-notify.sh'
SCRIPT="$PWD/home-manager/modules/local-scripts/pushover-notify.sh"

Describe 'when message is empty'
It 'exits 0 without sending'
When run bash "$SCRIPT" "Title"
The status should be success
End

It 'exits 0 with no arguments'
When run bash "$SCRIPT"
The status should be success
End
End

Describe 'when pushover is not configured'
It 'exits 0 silently'
When run bash -c "PUSHOVER_API_TOKEN='' PUSHOVER_USER_KEY='' bash '$SCRIPT' 'Title' 'Message'"
The status should be success
End
End

Describe 'when pushover is configured'
setup() {
  mock_bin_setup curl
}
cleanup() {
  mock_bin_cleanup
}
Before 'setup'
After 'cleanup'

It 'calls curl with correct parameters'
When run bash -c "PUSHOVER_API_TOKEN=test_token PUSHOVER_USER_KEY=test_user bash '$SCRIPT' 'My Title' 'Hello world' 1; cat \"\$MOCK_LOG\""
The status should be success
The output should include 'curl'
The output should include 'api.pushover.net'
End
End
End
