#!/usr/bin/env bash
# shellcheck disable=SC2329

Describe 'sync-rtk-rewrite.sh'
SCRIPT="$PWD/scripts/sync-rtk-rewrite.sh"

It 'is executable'
The path "$SCRIPT" should be executable
End

It 'contains curl to raw.githubusercontent.com'
When run bash -c "grep -q 'raw.githubusercontent.com/rtk-ai/rtk' '$SCRIPT' && echo found"
The output should eq 'found'
End
End
