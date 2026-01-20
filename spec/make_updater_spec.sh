#!/usr/bin/env bash
# shellcheck disable=SC2329

Describe 'make-updater/update.sh'
SCRIPT="$PWD/home-manager/services/make-updater/update.sh"

Describe 'script properties'
It 'uses bash shebang'
When run bash -c "head -1 '$SCRIPT'"
The output should include '#!/usr/bin/env bash'
End

It 'uses strict mode'
When run bash -c "head -5 '$SCRIPT'"
The output should include 'set -euo pipefail'
End

It 'changes to ~/dotfiles directory'
When run bash -c "grep 'cd ~/dotfiles' '$SCRIPT'"
The output should include 'cd ~/dotfiles'
End
End

Describe 'make update execution'
It 'runs make update'
When run bash -c "grep 'make update' '$SCRIPT'"
The output should include 'make update'
End
End

End
