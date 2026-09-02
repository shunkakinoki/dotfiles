#!/usr/bin/env bash
# shellcheck disable=SC2016,SC2329

Describe 'managed hyprlock integration'
MODULE="$PWD/config/noctalia/default.nix"
MATIC="$PWD/named-hosts/matic/default.nix"
WALKER="$PWD/config/walker/config.toml"
LOCK_SCRIPT="$PWD/config/noctalia/lock-screen.sh"

It 'installs a stable lock-screen command without a Home Manager service'
When run bash -c "grep -F 'name = \"lock-screen\";' '$MODULE' && ! grep -F 'systemd.user.services.hyprlock = {' '$MODULE'"
The output should include 'name = "lock-screen";'
The output should not include 'systemd.user.services.hyprlock'
End

It 'runs hyprlock as a transient unit with a clean library environment'
When run bash -c "grep -F -- '--unit=hyprlock.service' '$LOCK_SCRIPT' && grep -F -- '--collect' '$LOCK_SCRIPT' && grep -F -- '--property=UnsetEnvironment=LD_LIBRARY_PATH' '$LOCK_SCRIPT'"
The output should include '--unit=hyprlock.service'
The output should include '--collect'
The output should include 'UnsetEnvironment=LD_LIBRARY_PATH'
End

It 'makes repeated and concurrent lock requests idempotent'
When run bash -c "grep -Fc 'systemctl --user is-active --quiet hyprlock.service' '$LOCK_SCRIPT'"
The output should eq '2'
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

It 'routes Walker lock actions through the transient command'
When run bash -c "grep -F '\"Lock Screen\" = \"lock-screen\"' '$WALKER' && grep -F '\"Start Screen Saver\" = \"lock-screen\"' '$WALKER'"
The output should include 'Lock Screen'
The output should include 'Start Screen Saver'
End

End
