#!/usr/bin/env bash
# shellcheck disable=SC2329

Describe 'osd-brightness.sh'
SCRIPT="$PWD/config/hyprland/scripts/osd-brightness.sh"

Describe 'script structure'
It 'has a bash shebang'
When run bash -c "head -1 '$SCRIPT'"
The output should include '#!/usr/bin/env bash'
End

It 'handles raise action'
When run bash -c "grep -c 'raise' '$SCRIPT'"
The output should eq '2'
End

It 'handles lower action'
When run bash -c "grep -c 'lower' '$SCRIPT'"
The output should eq '2'
End

It 'uses brightnessctl for brightness control'
When run bash -c "cat '$SCRIPT'"
The output should include 'brightnessctl'
End

It 'writes to wob pipe for OSD display'
When run bash -c "cat '$SCRIPT'"
The output should include 'wobpipe'
End

It 'shows usage on invalid argument'
When run bash -c "cat '$SCRIPT'"
The output should include 'Usage:'
End
End

Describe 'argument validation'
setup() {
  mock_bin_setup brightnessctl
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
