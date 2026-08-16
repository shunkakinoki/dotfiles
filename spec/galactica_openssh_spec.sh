#!/usr/bin/env bash
# shellcheck disable=SC2329

Describe 'named-hosts/galactica/default.nix OpenSSH'
CONFIG="$PWD/named-hosts/galactica/default.nix"

It 'enables the built-in OpenSSH server for tailnet access'
When run bash -c "grep -F 'services.openssh.enable = true;' '$CONFIG'"
The output should include 'services.openssh.enable = true;'
End

End
