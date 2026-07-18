#!/usr/bin/env bash
# shellcheck disable=SC2329

Describe 'config/k3s/containerd-cleanup.sh'
SCRIPT="$PWD/config/k3s/containerd-cleanup.sh"

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

Describe 'crictl configuration'
It 'uses the k3s bundled crictl binary'
When run bash -c "grep -F 'crictl_bin=/var/lib/rancher/k3s/data/current/bin/crictl' '$SCRIPT'"
The output should include '/var/lib/rancher/k3s/data/current/bin/crictl'
End

It 'targets the k3s containerd socket'
When run bash -c "grep -F 'runtime_endpoint=unix:///run/k3s/containerd/containerd.sock' '$SCRIPT'"
The output should include '/run/k3s/containerd/containerd.sock'
End

It 'fails fast when crictl is unavailable'
When run bash -c "grep -F 'if [ ! -x \"\$crictl_bin\" ]; then' '$SCRIPT'"
The output should include 'crictl_bin'
End
End

Describe 'cleanup deadlines'
It 'sets a crictl request timeout'
When run bash -c "grep -F 'crictl_timeout=10s' '$SCRIPT'"
The output should include 'crictl_timeout=10s'
End

It 'sets an outer command timeout'
When run bash -c "grep -F 'command_timeout=12' '$SCRIPT'"
The output should include 'command_timeout=12'
End

It 'wraps crictl calls in timeout'
When run bash -c "grep -c -F 'timeout \"\$command_timeout\"' '$SCRIPT'"
The output should not eq '0'
End
End

Describe 'cleanup behaviour'
It 'lists exited containers'
When run bash -c "grep -F 'ps -a --state Exited -q' '$SCRIPT'"
The output should include '--state Exited'
End

It 'force removes exited containers'
When run bash -c "grep -F 'rm -f \"\$container_id\"' '$SCRIPT'"
The output should include 'rm -f'
End

It 'lists not-ready sandboxes'
When run bash -c "grep -F 'pods --state NotReady -q' '$SCRIPT'"
The output should include '--state NotReady'
End

It 'force removes not-ready sandboxes'
When run bash -c "grep -F 'rmp -f \"\$sandbox_id\"' '$SCRIPT'"
The output should include 'rmp -f'
End

It 'tolerates individual removal failures'
When run bash -c "grep -c -F '|| true' '$SCRIPT'"
The output should not eq '0'
End

It 'reports completion'
When run bash -c "grep -F 'containerd cleanup complete' '$SCRIPT'"
The output should include 'containerd cleanup complete'
End
End

End
