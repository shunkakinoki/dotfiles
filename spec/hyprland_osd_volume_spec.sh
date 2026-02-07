#!/usr/bin/env bash
# shellcheck disable=SC2329

Describe 'osd-volume.sh'
SCRIPT="$PWD/config/hyprland/scripts/osd-volume.sh"

Describe 'script structure'
It 'has a bash shebang'
When run bash -c "head -1 '$SCRIPT'"
The output should include '#!/usr/bin/env bash'
End

It 'handles up action'
When run bash -c "cat '$SCRIPT'"
The output should include 'up)'
End

It 'handles down action'
When run bash -c "cat '$SCRIPT'"
The output should include 'down)'
End

It 'handles mute action'
When run bash -c "cat '$SCRIPT'"
The output should include 'mute)'
End

It 'uses wpctl for volume control'
When run bash -c "cat '$SCRIPT'"
The output should include 'wpctl'
End

It 'writes to wob pipe for OSD display'
When run bash -c "cat '$SCRIPT'"
The output should include 'wobpipe'
End

It 'shows usage on invalid argument'
When run bash -c "cat '$SCRIPT'"
The output should include 'Usage:'
End

It 'caps volume at 100 percent'
When run bash -c "cat '$SCRIPT'"
The output should include '-l 1.0'
End
End

Describe 'argument validation'
setup() {
  mock_bin_setup wpctl
}
cleanup() {
  mock_bin_cleanup
}
Before 'setup'
After 'cleanup'

It 'exits with error on unknown action'
When run bash "$SCRIPT" invalid
The status should be failure
The output should include 'Usage:'
End
End

End
