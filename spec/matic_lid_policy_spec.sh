#!/usr/bin/env bash
# shellcheck disable=SC2329

Describe 'named-hosts/matic/default.nix lid policy'
CONFIG="$PWD/named-hosts/matic/default.nix"

It 'hibernates on battery lid close'
When run bash -c "grep -F 'services.logind.settings.Login.HandleLidSwitch = \"hibernate\";' '$CONFIG'"
The output should include 'HandleLidSwitch = "hibernate"'
End

It 'lets Hyprland handle lid close while on AC power'
When run bash -c "grep -F 'services.logind.settings.Login.HandleLidSwitchExternalPower = \"ignore\";' '$CONFIG'"
The output should include 'HandleLidSwitchExternalPower = "ignore"'
End

End
