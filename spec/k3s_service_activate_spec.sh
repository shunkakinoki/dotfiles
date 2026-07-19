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
MOUNT_UNIT="$PWD/config/k3s/containerd.mount"

It 'restarts k3s after an unexpected exit'
When run grep '^Restart=always$' "$SERVICE"
The output should include 'Restart=always'
The status should be success
End

It 'requires the dedicated containerd mount'
When run grep '^Requires=var-lib-rancher-k3s-agent-containerd.mount$' "$SERVICE"
The output should include 'Requires=var-lib-rancher-k3s-agent-containerd.mount'
The status should be success
End

It 'mounts the labeled SSD at the containerd path'
When run bash -c "grep -qxF 'What=/dev/disk/by-label/k3s-containerd' '$MOUNT_UNIT' && grep -qxF 'Where=/var/lib/rancher/k3s/agent/containerd' '$MOUNT_UNIT'"
The status should be success
End

It 'does not allow a missing SSD to fall back to root'
When run grep -E '^Options=.*nofail' "$MOUNT_UNIT"
The status should equal 1
End

Describe 'container garbage collection ownership'
It 'does not configure external CRI garbage collection'
When run bash -c "! grep -R -q 'crictl\|containerd-cleanup\|pods --state NotReady' config/k3s home-manager/services/k3s"
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

It 'returns success when sudo is available'
When run bash -c "sed -n '/^require_sudo()/,/^}/p' '$SCRIPT' | grep -xF '  return 0'"
The output should include 'return 0'
The status should be success
End
End

Describe 'k3s setup'
SERVER_MODULE="$PWD/config/k3s/default.nix"

It 'installs the generated systemd service'
When run bash -c "grep '/etc/systemd/system/k3s.service' '$SCRIPT'"
The output should include '/etc/systemd/system/k3s.service'
End

It 'installs and starts the dedicated containerd mount first'
When run bash -c "grep '/etc/systemd/system/var-lib-rancher-k3s-agent-containerd.mount' '$SCRIPT' && grep 'enable --now var-lib-rancher-k3s-agent-containerd.mount' '$SCRIPT'"
The output should include 'var-lib-rancher-k3s-agent-containerd.mount'
The status should be success
End

It 'orders the k3s config hook after the mount hook'
When run grep 'entryAfter \[ "setupK3s" \]' "$SERVER_MODULE"
The output should include 'entryAfter [ "setupK3s" ]'
The status should be success
End

It 'refuses to hide a running or non-empty containerd directory'
When run bash -c "grep -q 'Refusing to mount the containerd SSD while k3s is running' '$SCRIPT' && grep -q 'Refusing to hide a non-empty containerd directory' '$SCRIPT'"
The status should be success
End

It 'inspects the root-owned containerd directory through sudo'
When run grep "run_sudo @find@ \"\$MOUNT_POINT\"" "$SCRIPT"
The output should include "run_sudo @find@ \"\$MOUNT_POINT\""
The status should be success
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

It 'keeps one percent of the ext4 root volume reserved'
When run bash -c "grep -xF '  local target_reserved_percent=1' '$SCRIPT'"
The output should include 'target_reserved_percent=1'
End

It 'resolves the mounted root block device instead of hard-coding it'
When run bash -c "grep '@findmnt@ --noheadings --output SOURCE --target /' '$SCRIPT'"
The output should include '@findmnt@ --noheadings --output SOURCE --target /'
End
End

Describe 'named-hosts/kyber/prepare-containerd-disk.sh'
PREPARE_SCRIPT="$PWD/named-hosts/kyber/prepare-containerd-disk.sh"

It 'requires explicit destructive confirmation'
When run grep -- '--confirm-wipe' "$PREPARE_SCRIPT"
The output should include '--confirm-wipe'
The status should be success
End

It 'refuses to run while k3s is active'
When run grep 'systemctl is-active --quiet k3s' "$PREPARE_SCRIPT"
The output should include 'systemctl is-active --quiet k3s'
The status should be success
End

It 'creates the stable containerd filesystem label'
When run grep "mkfs.ext4 -F -L \"\$MOUNT_LABEL\"" "$PREPARE_SCRIPT"
The output should include "mkfs.ext4 -F -L \"\$MOUNT_LABEL\""
The status should be success
End

It 'inspects the root-owned target through sudo'
When run grep "sudo find \"\$MOUNT_POINT\"" "$PREPARE_SCRIPT"
The output should include "sudo find \"\$MOUNT_POINT\""
The status should be success
End

It 'reuses the label only when it resolves to the selected device'
When run bash -c "grep -q 'existing_label_device=.*readlink -f' '$PREPARE_SCRIPT' && grep -q '\"\$existing_label_device\" != \"\$resolved_device\"' '$PREPARE_SCRIPT'"
The status should be success
End
End
End
