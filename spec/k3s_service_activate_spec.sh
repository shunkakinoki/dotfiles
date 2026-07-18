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

Describe 'config/k3s/k3s.service'
SERVICE="$PWD/config/k3s/k3s.service"

It 'restarts k3s after an unexpected exit'
When run grep '^Restart=always$' "$SERVICE"
The output should include 'Restart=always'
The status should be success
End

Describe 'containerd cleanup timer'
It 'installs cleanup as a host-level systemd timer'
When run bash -c "grep -q 'k3s-containerd-cleanup.service' home-manager/services/k3s/activate.sh && grep -q 'enable --now k3s-containerd-cleanup.timer' home-manager/services/k3s/activate.sh"
The status should be success
End

It 'only removes exited containers and not-ready sandboxes'
When run bash -c "grep -q 'ps -a --state Exited' config/k3s/containerd-cleanup.sh && grep -q 'pods --state NotReady' config/k3s/containerd-cleanup.sh"
The status should be success
End

It 'bounds every runtime cleanup operation'
When run bash -c "[ \"$(grep -c -- '--timeout.*crictl_timeout' config/k3s/containerd-cleanup.sh)\" -eq 4 ]"
The status should be success
End

It 'does not start k3s when the cleanup timer fires during maintenance'
When run grep -q '^Requisite=k3s.service$' config/k3s/containerd-cleanup.service
The status should be success
End
End

It 'does not run the destructive killall helper after service exit'
When run grep 'ExecStopPost=.*k3s-killall' "$SERVICE"
The status should equal 1
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
