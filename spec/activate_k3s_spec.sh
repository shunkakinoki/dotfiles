#!/usr/bin/env bash
# shellcheck disable=SC2329

Describe 'config/k3s/activate.sh'
SCRIPT="$PWD/config/k3s/activate.sh"

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

It 'warns when sudo not found'
When run bash -c "grep 'sudo not found' '$SCRIPT'"
The output should include 'sudo not found'
End
End

Describe 'config sync'
It 'creates /etc/rancher/k3s directory'
When run bash -c "grep '/etc/rancher/k3s' '$SCRIPT'"
The output should include '/etc/rancher/k3s'
End

It 'copies config.yaml'
When run bash -c "grep 'config.yaml' '$SCRIPT'"
The output should include 'config.yaml'
End

It 'skips if config file missing'
When run bash -c "grep -A 1 '! -f' '$SCRIPT'"
The output should include 'exit 0'
End
End
End
