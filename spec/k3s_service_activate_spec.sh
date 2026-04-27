#!/usr/bin/env bash
# shellcheck disable=SC2329

Describe 'home-manager/services/k3s/activate.sh'
SCRIPT="$PWD/home-manager/services/k3s/activate.sh"

Describe 'script properties'
It 'uses bash shebang'
When run bash -c "head -1 '$SCRIPT'"
The output should include '#!/usr/bin/env bash'
End

It 'uses strict mode'
When run bash -c "grep 'set -euo pipefail' '$SCRIPT'"
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

It 'warns when sudo is unavailable'
When run bash -c "grep 'sudo not found' '$SCRIPT'"
The output should include 'sudo not found'
End
End

Describe 'k3s setup'
It 'installs the generated systemd service'
When run bash -c "grep '/etc/systemd/system/k3s.service' '$SCRIPT'"
The output should include '/etc/systemd/system/k3s.service'
End

It 'reloads and enables k3s'
When run bash -c "grep 'enable --now k3s' '$SCRIPT'"
The output should include 'enable --now k3s'
End

It 'syncs kubeconfig into the user kube directory'
When run bash -c "grep '/etc/rancher/k3s/k3s.yaml' '$SCRIPT'"
The output should include '/etc/rancher/k3s/k3s.yaml'
End

It 'preserves dry-run command handling'
When run bash -c "grep 'DRY_RUN_CMD' '$SCRIPT'"
The output should include 'DRY_RUN_CMD'
End
End
End
