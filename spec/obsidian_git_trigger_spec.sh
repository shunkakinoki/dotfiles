#!/usr/bin/env bash
# shellcheck disable=SC2329

Describe 'home-manager/services/obsidian/obsidian-git-trigger.sh'
SCRIPT="$PWD/home-manager/services/obsidian/obsidian-git-trigger.sh"

Describe 'script properties'
It 'uses bash shebang'
When run bash -c "head -1 '$SCRIPT'"
The output should include '#!/usr/bin/env bash'
End

It 'passes bash syntax check after replacing placeholders'
When run bash -c "sed -e 's|@coreutils@|/usr|g' -e 's|@git@|/usr|g' -e 's|@utilLinux@|/usr|g' -e 's|@vaultDir@|/tmp/wiki|g' '$SCRIPT' | bash -n"
The status should be success
End
End

Describe 'placeholder references'
It 'references git via placeholder'
When run bash -c "grep '@git@' '$SCRIPT'"
The output should include '@git@'
End

It 'references flock via placeholder'
When run bash -c "grep '@utilLinux@' '$SCRIPT'"
The output should include '@utilLinux@'
End
End

Describe 'Git synchronization'
It 'serializes overlapping timer runs'
When run bash -c "grep 'flock -n' '$SCRIPT'"
The output should include 'flock -n'
End

It 'rebases before pushing main'
When run bash -c "grep 'rebase origin/main' '$SCRIPT'"
The output should include 'rebase origin/main'
End

It 'disables interactive signing for unattended commits'
When run bash -c "grep 'commit.gpgsign=false' '$SCRIPT'"
The output should include 'commit.gpgsign=false'
End

It 'fails when the vault is not a Git checkout'
When run bash -c "grep 'vault is not a Git checkout' '$SCRIPT'"
The output should include 'vault is not a Git checkout'
End
End

End
