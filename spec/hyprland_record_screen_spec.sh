#!/usr/bin/env bash
# shellcheck disable=SC2329

Describe 'record-screen.sh'
SCRIPT="$PWD/config/hyprland/scripts/record-screen.sh"

Describe 'script structure'
It 'has a bash shebang'
When run bash -c "head -1 '$SCRIPT'"
The output should include '#!/usr/bin/env bash'
End

It 'uses wf-recorder for screen recording'
When run bash -c "cat '$SCRIPT'"
The output should include 'wf-recorder'
End

It 'uses slurp for region selection'
When run bash -c "cat '$SCRIPT'"
The output should include 'slurp'
End

It 'saves recordings to Videos directory'
When run bash -c "cat '$SCRIPT'"
The output should include 'Videos'
End

It 'uses a PID file for toggle behavior'
When run bash -c "cat '$SCRIPT'"
The output should include 'wf-recorder.pid'
End

It 'sends notification on recording stop'
When run bash -c "cat '$SCRIPT'"
The output should include 'notify-send'
End

It 'timestamps recording filenames'
When run bash -c "cat '$SCRIPT'"
The output should include 'date'
End
End

End
