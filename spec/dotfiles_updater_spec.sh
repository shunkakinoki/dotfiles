#!/usr/bin/env bash
# shellcheck disable=SC2329

Describe 'dotfiles-updater/update.sh'
SCRIPT="$PWD/home-manager/services/dotfiles-updater/update.sh"

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

Describe 'branch detection'
It 'checks current branch name'
When run bash -c "grep 'rev-parse --abbrev-ref HEAD' '$SCRIPT'"
The output should include 'rev-parse --abbrev-ref HEAD'
End

It 'skips update when not on main'
When run bash -c "grep 'not main' '$SCRIPT'"
The output should include 'not main'
End

It 'exits cleanly when skipping'
When run bash -c "grep -A 1 'not main' '$SCRIPT'"
The output should include 'exit 0'
End
End

Describe 'git operations'
It 'fetches from origin main'
When run bash -c "grep 'git fetch origin main' '$SCRIPT'"
The output should include 'git fetch origin main'
End

It 'resets to origin/main'
When run bash -c "grep 'git reset --hard origin/main' '$SCRIPT'"
The output should include 'git reset --hard origin/main'
End
End

Describe 'installation'
It 'runs install.sh after update'
When run bash -c "grep './install.sh' '$SCRIPT'"
The output should include './install.sh'
End
End

End
