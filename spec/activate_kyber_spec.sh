#!/usr/bin/env bash
# shellcheck disable=SC2016,SC2329

Describe 'named-hosts/kyber/activate-backup-files.sh'
SCRIPT="$PWD/named-hosts/kyber/activate-backup-files.sh"

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

Describe 'backup behavior'
It 'backs up bash configuration files'
When run bash -c "grep '.bashrc' '$SCRIPT'"
The output should include '.bashrc'
End

It 'skips symlinks'
When run bash -c "grep -- '! -L' '$SCRIPT'"
The output should include '! -L'
End
End
End

Describe 'named-hosts/kyber/activate-ip-forwarding.sh'
SCRIPT="$PWD/named-hosts/kyber/activate-ip-forwarding.sh"

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

Describe 'sudo/doas detection'
It 'checks for sudo'
When run bash -c "grep 'command -v sudo' '$SCRIPT'"
The output should include 'command -v sudo'
End

It 'checks for doas as fallback'
When run bash -c "grep 'command -v doas' '$SCRIPT'"
The output should include 'command -v doas'
End

It 'checks NixOS wrapper path'
When run bash -c "grep '/run/wrappers/bin/sudo' '$SCRIPT'"
The output should include '/run/wrappers/bin/sudo'
End

It 'fails when no root access available'
When run bash -c "grep 'exit 1' '$SCRIPT'"
The output should include 'exit 1'
End
End

Describe 'IP forwarding'
It 'enables IPv4 forwarding'
When run bash -c "grep 'ip_forward' '$SCRIPT'"
The output should include 'net.ipv4.ip_forward'
End

It 'enables IPv6 forwarding'
When run bash -c "grep 'ipv6' '$SCRIPT'"
The output should include 'net.ipv6.conf.all.forwarding'
End

It 'creates persistent sysctl config'
When run bash -c "grep '99-tailscale.conf' '$SCRIPT'"
The output should include '99-tailscale.conf'
End
End

Describe 'activation wrapper quoting'
It 'quotes shared helper arguments that include the home directory'
When run cat "$PWD/named-hosts/kyber/default.nix"
The output should include '"${config.home.homeDirectory}/.ssh"'
End

It 'quotes the agenix config directory argument'
When run cat "$PWD/named-hosts/kyber/default.nix"
The output should include '"${config.home.homeDirectory}/.config/agenix"'
End
End
End
