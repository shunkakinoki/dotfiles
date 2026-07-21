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

It 'detects the public interface from the default route'
When run bash -c "grep 'route show default' '$SCRIPT'"
The output should include 'route show default'
End

It 'allows KYBER_PUBLIC_IF override'
When run bash -c "grep 'KYBER_PUBLIC_IF' '$SCRIPT'"
The output should include 'KYBER_PUBLIC_IF'
End

It 'allows established connections'
When run bash -c "grep 'ESTABLISHED,RELATED' '$SCRIPT'"
The output should include 'ESTABLISHED,RELATED'
End

It 'does not allow public SSH on the WAN chain'
When run bash -c "grep -E 'dport[[:space:]]+22' '$SCRIPT' || true"
The output should equal ''
End

It 'drops other traffic'
When run bash -c "grep -- '-j DROP' '$SCRIPT'"
The output should include 'DROP'
End

It 'reconverges by flushing the chain'
When run bash -c "grep -- '-F \"\$CHAIN\"' '$SCRIPT'"
The output should include '-F'
End

It 'programs ip6tables as well as iptables'
When run bash -c "grep '@ip6tables@' '$SCRIPT' && grep 'ensure_chain ip6t' '$SCRIPT'"
The output should include '@ip6tables@'
The output should include 'ensure_chain ip6t'
End

It 'uses nix-substituted iptables and ip paths'
When run bash -c "grep '@iptables@' '$SCRIPT' && grep '@ip@' '$SCRIPT'"
The output should include '@iptables@'
The output should include '@ip@'
End
End
End
