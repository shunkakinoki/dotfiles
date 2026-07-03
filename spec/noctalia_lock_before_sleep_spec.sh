#!/usr/bin/env bash
# shellcheck disable=SC2016,SC2329

Describe 'config/noctalia/lock-before-sleep.sh'
SCRIPT="$PWD/config/noctalia/lock-before-sleep.sh"

It 'uses bash strict mode'
When run bash -c "head -5 '$SCRIPT'"
The output should include 'set -euo pipefail'
End

It 'uses injected command paths'
When run bash -c "cat '$SCRIPT'"
The output should include '@noctalia@'
The output should include '@sleep@'
End

It 'calls Noctalia lock IPC before sleeping'
When run bash -c "cat '$SCRIPT'"
The output should include 'msg session lock'
The output should include '"$SLEEP" 1'
End

End
