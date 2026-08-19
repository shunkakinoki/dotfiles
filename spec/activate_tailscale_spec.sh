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

It 'accepts an optional tailscale-up unit'
When run bash -c "grep 'tailscale_up_service_file' '$SCRIPT'"
The output should include 'tailscale_up_service_file'
End

It 'enables and restarts tailscale-up after installing it'
When run bash -c "grep 'enable tailscale-up.service' '$SCRIPT' && grep 'restart tailscale-up.service' '$SCRIPT'"
The output should include 'restart tailscale-up.service'
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

Describe 'home-manager/modules/tailscale/default.nix'
MODULE="$PWD/home-manager/modules/tailscale/default.nix"

It 'delegates tailscale-up to the external activate script'
When run bash -c "grep 'activate-up.sh' '$MODULE' && grep 'bin/bash' '$MODULE'"
The output should include 'activate-up.sh'
End

It 'does not wrap tailscale-up in an inline writeShellScript'
When run bash -c "grep -E 'writeShellScript[[:space:]]+\"tailscale-up\"' '$MODULE' || true"
The output should equal ''
End
End

Describe 'home-manager/modules/tailscale/activate-up.sh'
SCRIPT="$PWD/home-manager/modules/tailscale/activate-up.sh"

Describe 'script properties'
It 'uses bash shebang'
When run bash -c "head -1 '$SCRIPT'"
The output should include '#!/usr/bin/env bash'
End

It 'uses strict mode'
When run bash -c "head -10 '$SCRIPT'"
The output should include 'set -euo pipefail'
End
End

Describe 'flag application'
It 'requires a tailscale binary argument'
When run bash -c "grep 'tailscale binary required' '$SCRIPT'"
The output should include 'tailscale binary required'
End

It 'runs tailscale up with the remaining args'
When run bash -c "grep 'TAILSCALE_BIN\" up' '$SCRIPT'"
The output should include 'up'
End

It 'retries tailscale up before giving up'
When run bash -c "grep 'attempt' '$SCRIPT' && grep 'sleep 2' '$SCRIPT'"
The output should include 'sleep 2'
End
End

Describe 'dns restore'
It 'detects --accept-dns=false'
When run bash -c "grep -F -- '--accept-dns=false' '$SCRIPT'"
The output should include '--accept-dns=false'
End

It 'forces accept-dns off even if up already ran'
When run bash -c "grep -F -- 'set --accept-dns=false' '$SCRIPT'"
The output should include 'set --accept-dns=false'
End

It 'restores the systemd-resolved stub resolv.conf'
When run bash -c "grep 'stub-resolv.conf' '$SCRIPT' && grep 'ln -sfn' '$SCRIPT'"
The output should include 'stub-resolv.conf'
End

It 'skips restore when already pointing at the stub'
When run bash -c "grep 'readlink -f' '$SCRIPT'"
The output should include 'readlink -f'
End
End
End
