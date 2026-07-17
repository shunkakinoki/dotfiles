#!/usr/bin/env bash
# shellcheck disable=SC2016,SC2329

Describe 'Makefile nix-build host resolution'

setup() {
  mock_bin_setup nix sleep
}

cleanup() {
  mock_bin_cleanup
}

Before 'setup'
After 'cleanup'

It 'uses an explicit named NixOS host on Darwin builds'
When run bash -c 'make build HOST=matic OS=Darwin ARCH=arm64 DETECTED_HOST=galactica NIX_EXEC=nix NIX_ENV=ok NIX_FLAGS= NIX_USER_TRUSTED=yes 2>/dev/null; cat "$MOCK_LOG"'
The status should be success
The output should include '.#nixosConfigurations.matic.config.system.build.toplevel'
The output should not include '.#darwinConfigurations.galactica.system'
End

It 'falls back to the detected Darwin host when HOST is unset'
When run bash -c 'make build OS=Darwin ARCH=arm64 DETECTED_HOST=galactica NIX_EXEC=nix NIX_ENV=ok NIX_FLAGS= NIX_USER_TRUSTED=yes 2>/dev/null; cat "$MOCK_LOG"'
The status should be success
The output should include '.#darwinConfigurations.galactica.system'
The output should not include '.#nixosConfigurations.matic.config.system.build.toplevel'
End

It 'detects matic from Framework 13 AMD AI 300 DMI data when the hostname is generic'
When run bash -c 'make build OS=Linux ARCH=x86_64 NIX_SYSTEM=x86_64-linux NIX_CONFIG_TYPE=nixosConfigurations DMI_SYS_VENDOR=Framework DMI_PRODUCT_NAME="Laptop 13 (AMD Ryzen AI 300 Series)" NIX_EXEC=nix NIX_ENV=ok NIX_FLAGS= NIX_USER_TRUSTED=yes SUDO=env 2>/dev/null; cat "$MOCK_LOG"'
The status should be success
The output should include '--flake .#matic'
The output should not include '--flake .#x86_64-linux'
End

It 'switches the detected matic host through the generic NixOS path'
When run bash -c 'make nix-switch OS=Linux ARCH=x86_64 NIX_SYSTEM=x86_64-linux NIX_CONFIG_TYPE=nixosConfigurations DMI_SYS_VENDOR=Framework DMI_PRODUCT_NAME="Laptop 13 (AMD Ryzen AI 300 Series)" NIX_EXEC=nix NIX_ENV=ok NIX_FLAGS= NIX_USER_TRUSTED=yes SUDO=env 2>/dev/null; cat "$MOCK_LOG"'
The status should be success
The output should include '-- switch --flake .#matic'
The output should not include '-- switch --flake .#x86_64-linux'
End

End
