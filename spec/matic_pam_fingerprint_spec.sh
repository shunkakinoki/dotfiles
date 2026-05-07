#!/usr/bin/env bash
# shellcheck disable=SC2329

Describe 'named-hosts/matic/default.nix Noctalia fingerprint PAM'
CONFIG="$PWD/named-hosts/matic/default.nix"

It 'keeps lock-screen fingerprint auth from timing out'
When run bash -c "awk '/security.pam.services.noctalia-shell = \\{/{in_service=1} in_service{print} in_service && /^        \\};/{exit}' '$CONFIG'"
The output should include 'fprintAuth = true;'
The output should include 'max-tries = -1;'
The output should include 'timeout = -1;'
End

End
