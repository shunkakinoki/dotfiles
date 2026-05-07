#!/usr/bin/env bash
# shellcheck disable=SC2329

Describe 'named-hosts/matic/default.nix lid policy'
CONFIG="$PWD/named-hosts/matic/default.nix"

It 'keeps battery lid close as suspend'
When run bash -c "grep -F 'services.logind.settings.Login.HandleLidSwitch = \"suspend\";' '$CONFIG'"
The output should include 'HandleLidSwitch = "suspend"'
End

It 'lets Hyprland handle lid close while on AC power'
When run bash -c "grep -F 'services.logind.settings.Login.HandleLidSwitchExternalPower = \"ignore\";' '$CONFIG'"
The output should include 'HandleLidSwitchExternalPower = "ignore"'
End

End
