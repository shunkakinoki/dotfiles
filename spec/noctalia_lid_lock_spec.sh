#!/usr/bin/env bash
# shellcheck disable=SC2016,SC2329

Describe 'config/noctalia/lid-lock.sh'
SCRIPT="$PWD/config/noctalia/lid-lock.sh"

It 'uses bash strict mode'
When run bash -c "head -5 '$SCRIPT'"
The output should include 'set -euo pipefail'
End

It 'uses injected command paths'
When run bash -c "cat '$SCRIPT'"
The output should include '@noctalia_shell@'
The output should include '@sleep@'
End

It 'reads the ACPI lid state file'
When run bash -c "cat '$SCRIPT'"
The output should include '/proc/acpi/button/lid/*/state'
End

It 'locks Noctalia on the closed transition'
When run bash -c "cat '$SCRIPT'"
The output should include 'ipc call lockScreen lock'
The output should include '[ "$lid_state" = closed ]'
The output should include '[ "$last_state" != closed ]'
End

End
