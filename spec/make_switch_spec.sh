#!/usr/bin/env bash
# shellcheck disable=SC2016,SC2329

Describe 'Makefile switch post-activation dependencies'
MAKEFILE="$PWD/Makefile"

It 'uses a switch-specific checked-in dotagents sync'
When run grep 'dotagents-switch-sync' "$MAKEFILE"
The output should include 'dotagents-switch-sync'
End

It 'initializes dotagents before syncing it'
When run bash -c "grep -A8 '^dotagents-prepare:' '$MAKEFILE'"
The output should include 'git submodule update --init dotagents'
End

It 'does not require the optional dotagents sync target during switch'
When run bash -c "grep -A2 '^dotagents-switch-sync:' '$MAKEFILE'"
The output should include 'DOTAGENTS_SKIP_SYNC=1'
End
End
