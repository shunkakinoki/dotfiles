#!/usr/bin/env bash
# shellcheck disable=SC2016,SC2329

Describe 'home-manager/modules/tailscale/activate-create-dirs.sh'
SCRIPT="$PWD/home-manager/modules/tailscale/activate-create-dirs.sh"

It 'uses bash shebang'
When run bash -c "head -1 '$SCRIPT'"
The output should include '#!/usr/bin/env bash'
End

It 'uses strict mode'
When run bash -c "head -5 '$SCRIPT'"
The output should include 'set -euo pipefail'
End

It 'creates state directory'
When run bash -c "grep 'STATE_DIR' '$SCRIPT'"
The output should include 'STATE_DIR="$1"'
End

It 'creates run directory'
When run bash -c "grep 'RUN_DIR' '$SCRIPT'"
The output should include 'RUN_DIR="$2"'
End

It 'sets permissions to 700'
When run bash -c "grep 'chmod 700' '$SCRIPT'"
The output should include 'chmod 700'
End
End

Describe 'home-manager/modules/tailscale/activate-install-service.sh'
SCRIPT="$PWD/home-manager/modules/tailscale/activate-install-service.sh"

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
It 'checks for sudo'
When run bash -c "grep 'command -v sudo' '$SCRIPT'"
The output should include 'command -v sudo'
End

It 'checks for doas'
When run bash -c "grep 'command -v doas' '$SCRIPT'"
The output should include 'command -v doas'
End
End

Describe 'service installation'
It 'compares service files before installing'
When run bash -c "grep 'cmp -s' '$SCRIPT'"
The output should include 'cmp -s'
End

It 'runs systemctl daemon-reload'
When run bash -c "grep 'daemon-reload' '$SCRIPT'"
The output should include 'daemon-reload'
End

It 'enables tailscaled service'
When run bash -c "grep 'systemctl enable tailscaled' '$SCRIPT'"
The output should include 'enable tailscaled'
End
End

Describe 'sudoers configuration'
It 'configures secure_path for nix'
When run bash -c "grep 'secure_path' '$SCRIPT'"
The output should include 'secure_path'
End

It 'sets sudoers file permissions to 0440'
When run bash -c "grep '0440' '$SCRIPT'"
The output should include '0440'
End

It 'cleans up temp file'
When run bash -c "grep 'rm -f.*TEMP_SUDOERS' '$SCRIPT'"
The output should include 'rm -f'
End
End
End
