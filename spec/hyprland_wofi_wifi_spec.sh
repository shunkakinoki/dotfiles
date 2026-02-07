#!/usr/bin/env bash
# shellcheck disable=SC2329

Describe 'wofi-wifi.sh'
SCRIPT="$PWD/config/hyprland/scripts/wofi-wifi.sh"

Describe 'script structure'
It 'has a bash shebang'
When run bash -c "head -1 '$SCRIPT'"
The output should include '#!/usr/bin/env bash'
End

It 'uses nmcli for network scanning'
When run bash -c "cat '$SCRIPT'"
The output should include 'nmcli'
End

It 'uses wofi as the picker interface'
When run bash -c "cat '$SCRIPT'"
The output should include 'wofi --dmenu'
End

It 'sends notifications via notify-send'
When run bash -c "cat '$SCRIPT'"
The output should include 'notify-send'
End

It 'handles secured networks with password prompt'
When run bash -c "cat '$SCRIPT'"
The output should include 'password'
End

It 'checks for currently active connection'
When run bash -c "cat '$SCRIPT'"
The output should include 'connection show --active'
End

It 'handles saved connections'
When run bash -c "cat '$SCRIPT'"
The output should include 'connection up'
End
End

End
