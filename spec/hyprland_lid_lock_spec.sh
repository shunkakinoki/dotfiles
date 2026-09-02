#!/usr/bin/env bash
# shellcheck disable=SC2329

Describe 'config/hyprland/hyprland.conf hyprlock bindings'
CONFIG="$PWD/config/hyprland/hyprland.conf"

It 'defines the managed hyprlock command'
When run bash -c "grep -F '\$lock = systemctl --user start hyprlock.service' '$CONFIG'"
The output should include 'hyprlock.service'
End

It 'locks through hyprlock when Hyprland reports the lid switch closing'
When run bash -c "grep -F 'bindl = , switch:on:Lid Switch, exec, \$lock' '$CONFIG'"
The output should include 'switch:on:Lid Switch'
The output should include 'exec, $lock'
End

It 'routes the power key through hyprlock'
When run bash -c "grep -F 'bindl = , XF86PowerOff, exec, \$lock' '$CONFIG'"
The output should include 'XF86PowerOff'
End

End
