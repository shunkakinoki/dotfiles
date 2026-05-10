#!/usr/bin/env bash
# shellcheck disable=SC2329

Describe 'config/k3s/activate-client.sh'
SCRIPT="$PWD/config/k3s/activate-client.sh"

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

Describe 'tailscale check'
It 'checks if tailscale is available'
When run bash -c "grep 'command -v tailscale' '$SCRIPT'"
The output should include 'command -v tailscale'
End

It 'checks tailscale status before proceeding'
When run bash -c "grep 'tailscale status' '$SCRIPT'"
The output should include 'tailscale status'
End
End

Describe 'kubeconfig fetch'
It 'uses scp to fetch kubeconfig'
When run bash -c "grep 'scp' '$SCRIPT'"
The output should include 'scp'
End

It 'targets the tailscale DNS host'
When run bash -c "grep 'tail950b36.ts.net' '$SCRIPT'"
The output should include 'tail950b36.ts.net'
End

It 'sets restrictive permissions on kubeconfig'
When run bash -c "grep 'chmod 600' '$SCRIPT'"
The output should include 'chmod 600'
End
End

Describe 'failure visibility'
It 'does not silently discard scp stderr'
When run bash -c "grep 'scp ' '$SCRIPT'"
The output should not include '2>/dev/null'
End

It 'logs scp failures to stderr'
When run bash -c "grep 'failed to fetch kubeconfig' '$SCRIPT'"
The output should include 'failed to fetch kubeconfig'
End
End
End
