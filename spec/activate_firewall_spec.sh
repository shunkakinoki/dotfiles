#!/usr/bin/env bash
# shellcheck disable=SC2329,SC2016

Describe 'home-manager/services/firewall/activate.sh'
SCRIPT="$PWD/home-manager/services/firewall/activate.sh"

Describe 'script properties'
It 'uses bash shebang'
When run bash -c "head -1 '$SCRIPT'"
The output should include '#!/usr/bin/env bash'
End

It 'uses strict mode'
When run bash -c "head -5 '$SCRIPT'"
The output should include 'set -euo pipefail'
End
End

Describe 'sudo detection'
It 'checks for sudo command'
When run bash -c "grep 'command -v sudo' '$SCRIPT'"
The output should include 'command -v sudo'
End

It 'checks NixOS wrapper path'
When run bash -c "grep '/run/wrappers/bin/sudo' '$SCRIPT'"
The output should include '/run/wrappers/bin/sudo'
End
End

Describe 'firewall configuration'
It 'defines a custom iptables chain name'
When run bash -c "grep 'CHAIN=' '$SCRIPT'"
The output should include 'kyber-firewall'
End

It 'targets the public interface'
When run bash -c "grep 'PUBLIC_IF=' '$SCRIPT'"
The output should include 'eno1'
End

It 'allows established connections'
When run bash -c "grep 'ESTABLISHED,RELATED' '$SCRIPT'"
The output should include 'ESTABLISHED,RELATED'
End

It 'allows SSH on port 22'
When run bash -c "grep 'dport 22' '$SCRIPT'"
The output should include 'dport 22'
End

It 'drops other traffic'
When run bash -c "grep -- '-j DROP' '$SCRIPT'"
The output should include 'DROP'
End

It 'is idempotent by checking chain existence'
When run bash -c "grep 'already exists' '$SCRIPT'"
The output should include 'already exists'
End

It 'uses a nix-substituted iptables path'
When run bash -c "grep '@iptables@' '$SCRIPT'"
The output should include '@iptables@'
End
End
End
