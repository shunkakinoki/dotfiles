#!/usr/bin/env bash
# shellcheck disable=SC2329

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
When run bash -c "make build HOST=matic OS=Darwin ARCH=arm64 DETECTED_HOST=galactica NIX_EXEC=nix NIX_ENV=ok NIX_FLAGS= NIX_USER_TRUSTED=yes 2>/dev/null; cat \"\$MOCK_LOG\""
The status should be success
The output should include '.#nixosConfigurations.matic.config.system.build.toplevel'
The output should not include '.#darwinConfigurations.galactica.system'
End

It 'falls back to the detected Darwin host when HOST is unset'
When run bash -c "make build OS=Darwin ARCH=arm64 DETECTED_HOST=galactica NIX_EXEC=nix NIX_ENV=ok NIX_FLAGS= NIX_USER_TRUSTED=yes 2>/dev/null; cat \"\$MOCK_LOG\""
The status should be success
The output should include '.#darwinConfigurations.galactica.system'
The output should not include '.#nixosConfigurations.matic.config.system.build.toplevel'
End

End
