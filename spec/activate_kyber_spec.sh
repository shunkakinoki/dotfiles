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

It 'deploys the galactica id_ed25519.age ciphertext'
When run bash -c "grep 'id_ed25519.age' '$PWD/named-hosts/kyber/default.nix'"
The output should include 'id_ed25519.age'
End

It 'hardens sshd during activation'
When run bash -c "grep 'activate-sshd.sh' '$PWD/named-hosts/kyber/default.nix'"
The output should include 'activate-sshd.sh'
End

It 'prioritizes managed services during activation'
When run bash -c "grep 'activate-user-service-priority.sh' '$PWD/named-hosts/kyber/default.nix'"
The output should include 'activate-user-service-priority.sh'
End

It 'keeps a long gpg-agent cache ttl'
When run bash -c "grep 'defaultCacheTtl = 94608000' '$PWD/named-hosts/kyber/default.nix'"
The output should include 'defaultCacheTtl = 94608000'
End

It 'does not enable Tailscale SSH'
When run bash -c "grep -F '\"--ssh\"' '$PWD/named-hosts/kyber/default.nix' || true"
The output should equal ''
End

It 'explicitly disables Tailscale SSH'
When run bash -c "grep -F '\"--ssh=false\"' '$PWD/named-hosts/kyber/default.nix'"
The output should include '--ssh=false'
End

It 'explicitly disables Tailscale DNS'
When run bash -c "grep -F '\"--accept-dns=false\"' '$PWD/named-hosts/kyber/default.nix'"
The output should include '--accept-dns=false'
End
End

Describe 'named-hosts/kyber/activate-user-service-priority.sh'
SCRIPT="$PWD/named-hosts/kyber/activate-user-service-priority.sh"

It 'installs system and user manager systemd drop-ins'
When run bash -c "grep -q 'system.slice.d/10-kyber-managed-services.conf' '$SCRIPT' && grep -q 'user@.*service.d/10-kyber-managed-services.conf' '$SCRIPT'"
The status should be success
End

It 'weights managed services above interactive session scopes'
When run bash -c "grep -q 'CPUWeight=1000' '$SCRIPT' && grep -q 'IOWeight=1000' '$SCRIPT'"
The status should be success
End

It 'applies the weights without restarting the user manager'
When run grep 'set-property --runtime' "$SCRIPT"
The output should include 'set-property --runtime'
End

It 'uses non-interactive privilege escalation'
When run bash -c "grep -q 'ROOT_CMD=(sudo -n)' '$SCRIPT' && grep -q 'ROOT_CMD=(doas -n)' '$SCRIPT'"
The status should be success
End

It 'skips redundant runtime property updates'
When run bash -c "grep -q 'systemctl show' '$SCRIPT' && grep -q '\[ \"\$cpu_weight\" = 1000 \].*\[ \"\$io_weight\" = 1000 \]' '$SCRIPT'"
The status should be success
End

It 'caps user.slice write bandwidth so a runaway writer cannot flood the journal'
When run bash -c "grep -q 'user.slice.d/10-kyber-io-ceiling.conf' '$SCRIPT' && grep -q 'IOWriteBandwidthMax' '$SCRIPT'"
The status should be success
End

It 'defaults the write ceiling but allows an override'
When run grep 'KYBER_USER_IO_WRITE_MAX:-150M' "$SCRIPT"
The output should include 'KYBER_USER_IO_WRITE_MAX:-150M'
End

It 'selects bfq so IOWeight is not inert under mq-deadline'
When run bash -c "grep -q 'select_bfq_scheduler' '$SCRIPT' && grep -q 'queue/scheduler' '$SCRIPT'"
The status should be success
End

It 'persists the scheduler choice through a udev rule'
When run bash -c "grep -q '60-kyber-bfq.rules' '$SCRIPT' && grep -q 'ATTR{queue/scheduler}=\"bfq\"' '$SCRIPT'"
The status should be success
End

It 'leaves the scheduler alone when bfq is already selected'
When run grep -F '*"[bfq]"*' "$SCRIPT"
The output should include '[bfq]'
End

It 'warns instead of failing when bfq is unavailable'
When run grep 'bfq unavailable on' "$SCRIPT"
The output should include 'IOWeight stays inert there'
End
End
End

Describe 'named-hosts/kyber/activate-sshd.sh'
SCRIPT="$PWD/named-hosts/kyber/activate-sshd.sh"

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

Describe 'hardening content'
It 'disables password authentication'
When run bash -c "grep 'PasswordAuthentication no' '$SCRIPT'"
The output should include 'PasswordAuthentication no'
End

It 'disables root login'
When run bash -c "grep 'PermitRootLogin no' '$SCRIPT'"
The output should include 'PermitRootLogin no'
End

It 'restricts AllowUsers to ubuntu'
When run bash -c "grep 'AllowUsers ubuntu' '$SCRIPT'"
The output should include 'AllowUsers ubuntu'
End

It 'writes an sshd_config.d drop-in'
When run bash -c "grep '99-kyber-hardening.conf' '$SCRIPT'"
The output should include '99-kyber-hardening.conf'
End

It 'validates config with sshd -t'
When run bash -c "grep 'sshd -t' '$SCRIPT'"
The output should include 'sshd -t'
End
End
End

Describe 'named-hosts/kyber/activate-fish-ssh-compat.sh'
SCRIPT="$PWD/named-hosts/kyber/activate-fish-ssh-compat.sh"

It 'stores the Fish terminal-query compatibility flag universally'
When run grep -F 'set --universal --append fish_features no-query-term' "$SCRIPT"
The output should include 'fish_features no-query-term'
End

It 'only appends the flag when it is absent'
When run grep -F 'contains -- no-query-term $fish_features' "$SCRIPT"
The output should include 'contains -- no-query-term'
End

It 'is activated by the Kyber Home Manager configuration'
When run grep -F 'activate-fish-ssh-compat.sh' "$PWD/named-hosts/kyber/default.nix"
The output should include 'activate-fish-ssh-compat.sh'
End
End

Describe 'config/k3s/tmp.mount'
UNIT="$PWD/config/k3s/kyber-tmp.mount"

It 'moves /tmp onto tmpfs'
When run bash -c "grep -q 'What=tmpfs' '$UNIT' && grep -q 'Where=/tmp' '$UNIT'"
The status should be success
End

It 'caps the tmpfs so a runaway job cannot consume host memory'
When run grep 'Options=' "$UNIT"
The output should include 'size=32G'
End

It 'keeps the sticky, nosuid, nodev semantics of a real /tmp'
When run bash -c "grep -q 'mode=1777' '$UNIT' && grep -q 'nosuid' '$UNIT' && grep -q 'nodev' '$UNIT'"
The status should be success
End

It 'installs into local-fs.target'
When run grep 'WantedBy=' "$UNIT"
The output should include 'local-fs.target'
End
End

Describe 'home-manager/services/k3s/activate.sh'
SCRIPT="$PWD/home-manager/services/k3s/activate.sh"

It 'installs the tmpfs mount unit'
When run bash -c "grep -q 'SYSTEM_TMP_MOUNT=' '$SCRIPT' && grep -q 'TMP_MOUNT_FILE:.SYSTEM_TMP_MOUNT' '$SCRIPT'"
The status should be success
End

It 'enables tmp.mount without mounting over a live /tmp'
When run bash -c "grep -q 'enable tmp.mount' '$SCRIPT' && ! grep -q 'enable --now tmp.mount' '$SCRIPT'"
The status should be success
End

It 'exposes smartctl on the sudo secure_path'
When run bash -c "grep -q '/usr/local/bin/smartctl' '$SCRIPT' && grep -q 'ln -sfn' '$SCRIPT'"
The status should be success
End
End

Describe 'config/k3s/kyber-host-health.sh'
SCRIPT="$PWD/config/k3s/kyber-host-health.sh"

It 'alerts before a disk exhausts its rated write endurance'
When run bash -c "grep -q 'check_disk_wear' '$SCRIPT' && grep -q 'DISK_WEAR_WARNING_PERCENT=10' '$SCRIPT'"
The status should be success
End

It 'reads remaining endurance from Wear_Leveling_Count'
When run grep 'Wear_Leveling_Count' "$SCRIPT"
The output should include 'Wear_Leveling_Count'
End

It 'rate-limits the SMART probe away from the one-minute timer'
When run grep 'DISK_WEAR_CHECK_INTERVAL_SECONDS' "$SCRIPT"
The output should include '21600'
End

It 'runs the wear check as part of main'
When run bash -c "awk '/^main\(\)/,/^}/' '$SCRIPT' | grep -q check_disk_wear"
The status should be success
End
End
