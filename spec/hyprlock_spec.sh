#!/usr/bin/env bash
# shellcheck disable=SC2016,SC2329

Describe 'managed hyprlock integration'
MODULE="$PWD/config/noctalia/default.nix"
MATIC="$PWD/named-hosts/matic/default.nix"
WALKER="$PWD/config/walker/config.toml"

It 'installs and manages hyprlock as a graphical-session service'
When run bash -c "grep -F 'systemd.user.services.hyprlock' '$MODULE' && grep -F 'ExecStart = \"\${pkgs.hyprlock}/bin/hyprlock --immediate-render\";' '$MODULE'"
The output should include 'systemd.user.services.hyprlock'
The output should include 'hyprlock --immediate-render'
End

It 'starts hyprlock before system sleep'
When run bash -c "grep -F 'systemd.user.services.hyprlock-before-sleep' '$MODULE' && grep -F 'ExecStart = \"\${pkgs.bash}/bin/bash \${lockBeforeSleep}\";' '$MODULE'"
The output should include 'hyprlock-before-sleep'
The output should include 'lockBeforeSleep'
End

It 'provides an authenticated visible lock configuration'
When run bash -c "grep -F 'xdg.configFile.\"hypr/hyprlock.conf\"' '$MODULE' && grep -F 'fingerprint:enabled = true' '$MODULE' && grep -F 'input-field {' '$MODULE'"
The output should include 'hypr/hyprlock.conf'
The output should include 'fingerprint:enabled = true'
The output should include 'input-field {'
End

It 'disables the crashing Noctalia lockscreen and routes idle locking to hyprlock'
When run bash -c "grep -A4 'lockscreen = {' '$MODULE' && grep -A5 'behavior.lock = {' '$MODULE'"
The output should include 'enabled = false'
The output should include 'command = lockCommand'
End

It 'configures fingerprint PAM authentication on Matic'
When run bash -c "grep -A2 'security.pam.services.hyprlock' '$MATIC'"
The output should include 'fprintAuth = true'
End

It 'routes Walker lock actions through the managed service'
When run bash -c "grep -F '\"Lock Screen\" = \"systemctl --user start hyprlock.service\"' '$WALKER' && grep -F '\"Start Screen Saver\" = \"systemctl --user start hyprlock.service\"' '$WALKER'"
The output should include 'Lock Screen'
The output should include 'Start Screen Saver'
End

End
