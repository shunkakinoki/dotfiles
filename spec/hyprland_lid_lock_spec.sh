#!/usr/bin/env bash
# shellcheck disable=SC2329

Describe 'config/hyprland/hyprland.conf lid lock binding'
CONFIG="$PWD/config/hyprland/hyprland.conf"

It 'locks Noctalia when Hyprland reports the lid switch closing'
When run bash -c "grep -F 'bindl = , switch:on:Lid Switch, exec, noctalia-shell ipc call lockScreen lock' '$CONFIG'"
The output should include 'switch:on:Lid Switch'
The output should include 'lockScreen lock'
End

End
