#!/usr/bin/env bash
# shellcheck disable=SC2329

Describe 'gas-town/start.sh'
SCRIPT="$PWD/home-manager/services/gas-town/start.sh"

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

Describe 'initialization'
It 'checks gt status before init'
When run bash -c "grep 'gt status' '$SCRIPT'"
The output should include 'gt status'
End

It 'runs gt init if not set up'
When run bash -c "grep 'gt init' '$SCRIPT'"
The output should include 'gt init'
End
End

Describe 'rig setup'
It 'checks for dotfiles rig'
When run bash -c "grep 'gt rig list' '$SCRIPT'"
The output should include 'gt rig list'
End

It 'adds dotfiles rig with adopt flag'
When run bash -c "grep 'gt rig add dotfiles --adopt' '$SCRIPT'"
The output should include 'gt rig add dotfiles --adopt'
End
End

Describe 'daemon startup'
It 'starts with exec gt up'
When run bash -c "grep 'exec gt up' '$SCRIPT'"
The output should include 'exec gt up'
End
End

End
