#!/usr/bin/env bash
# shellcheck disable=SC2329

Describe 'hosts/darwin/activate-remove-backups.sh'
SCRIPT="$PWD/hosts/darwin/activate-remove-backups.sh"

It 'uses bash shebang'
When run bash -c "head -1 '$SCRIPT'"
The output should include '#!/usr/bin/env bash'
End

It 'removes hm-backup files from .codex'
When run bash -c "grep 'hm-backup' '$SCRIPT'"
The output should include 'hm-backup'
End

It 'uses find -delete'
When run bash -c "grep -- '-delete' '$SCRIPT'"
The output should include '-delete'
End

It 'suppresses errors gracefully'
When run bash -c "grep '|| true' '$SCRIPT'"
The output should include '|| true'
End
End

Describe 'hosts/linux/activate-backup-files.sh'
SCRIPT="$PWD/hosts/linux/activate-backup-files.sh"

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
It 'backs up .bashrc'
When run bash -c "grep '.bashrc' '$SCRIPT'"
The output should include '.bashrc'
End

It 'backs up .profile'
When run bash -c "grep '.profile' '$SCRIPT'"
The output should include '.profile'
End

It 'backs up .bash_profile'
When run bash -c "grep '.bash_profile' '$SCRIPT'"
The output should include '.bash_profile'
End

It 'skips symlinks'
When run bash -c "grep -- '! -L' '$SCRIPT'"
The output should include '! -L'
End

It 'backs up openclaw config'
When run bash -c "grep 'openclaw' '$SCRIPT'"
The output should include 'openclaw.json'
End

It 'cleans up codex backups'
When run bash -c "grep 'codex' '$SCRIPT'"
The output should include 'hm-backup'
End
End
End
