#!/usr/bin/env bash
# shellcheck disable=SC2329,SC2034

Describe 'upgrade-overlays.sh'
SCRIPT="$PWD/scripts/upgrade-overlays.sh"

Describe 'usage and help'
It 'shows usage when called without arguments'
When run bash "$SCRIPT"
The output should include 'Usage:'
The output should include 'upgrade-overlays.sh'
The output should include 'all'
The status should be failure
End

It 'shows usage with --help flag'
When run bash "$SCRIPT" --help
The output should include 'Usage:'
The output should include 'Available commands:'
The status should be success
End

It 'shows usage with -h flag'
When run bash "$SCRIPT" -h
The output should include 'Usage:'
The status should be success
End
End

Describe 'unknown overlay handling'
It 'fails for unknown overlay'
When run bash "$SCRIPT" unknown-overlay
The output should include 'Unknown command: unknown-overlay'
The output should include 'Available commands'
The status should be failure
End
End

Describe 'all overlay target'
It 'reports no overlays configured'
When run bash "$SCRIPT" all
The output should include 'No overlay upgrades configured.'
The status should be success
End
End
End
