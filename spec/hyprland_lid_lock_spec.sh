#!/usr/bin/env bash
# shellcheck disable=SC2329

Describe 'config/hyprland/hyprland.conf lid lock binding'
CONFIG="$PWD/config/hyprland/hyprland.conf"

It 'locks Noctalia when Hyprland reports the lid switch closing'
When run bash -c "grep -F 'bindl = , switch:on:Lid Switch, exec, noctalia msg session lock' '$CONFIG'"
The output should include 'switch:on:Lid Switch'
The output should include 'msg session lock'
End

End
