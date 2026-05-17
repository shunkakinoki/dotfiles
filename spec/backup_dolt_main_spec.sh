#!/usr/bin/env bash
# shellcheck disable=SC2329

Describe 'home-manager/services/dolt/backup-dolt-main.sh'
SCRIPT="$PWD/home-manager/services/dolt/backup-dolt-main.sh"

Describe 'script properties'
It 'uses bash shebang'
When run bash -c "head -1 '$SCRIPT'"
The output should include '#!/usr/bin/env bash'
End

It 'uses strict mode'
When run bash -c "grep 'set -euo pipefail' '$SCRIPT'"
The output should include 'set -euo pipefail'
End

It 'passes bash syntax check after stripping placeholders'
When run bash -c "sed 's|@[A-Za-z_][A-Za-z0-9_]*@|/usr|g' '$SCRIPT' | bash -n"
The status should be success
End
End

Describe 'placeholder substitutions'
It 'references @git@'
When run bash -c "grep '@git@' '$SCRIPT'"
The output should include '@git@'
End

It 'references @mirrorDir@'
When run bash -c "grep '@mirrorDir@' '$SCRIPT'"
The output should include '@mirrorDir@'
End

It 'references @remoteUrl@'
When run bash -c "grep '@remoteUrl@' '$SCRIPT'"
The output should include '@remoteUrl@'
End

It 'references @userEmail@'
When run bash -c "grep '@userEmail@' '$SCRIPT'"
The output should include '@userEmail@'
End
End

Describe 'preflight checks'
It 'requires bd on PATH'
When run bash -c "grep 'command -v bd' '$SCRIPT'"
The output should include 'command -v bd'
End

It 'extends PATH for Nix profiles and user-local bins'
When run bash -c "grep 'export PATH=' '$SCRIPT'"
The output should include '.nix-profile/bin'
End
End

Describe 'mirror checkout management'
It 'creates the mirror parent directory'
When run bash -c "grep 'mkdir -p' '$SCRIPT'"
The output should include 'mkdir -p'
End

It 'clones the remote when the mirror is missing'
When run bash -c "grep 'clone --depth 1' '$SCRIPT'"
The output should include 'clone --depth 1'
End

It 'resets the mirror to origin/main before exporting'
When run bash -c "grep 'reset --hard origin/main' '$SCRIPT'"
The output should include 'reset --hard origin/main'
End
End

Describe 'export and push'
It 'exports the full beads dataset'
When run bash -c "grep -- 'bd --global export --all' '$SCRIPT'"
The output should include 'bd --global export --all'
End

It 'writes to a temporary file before renaming'
When run bash -c "grep 'issues.jsonl.tmp' '$SCRIPT'"
The output should include 'issues.jsonl.tmp'
End

It 'skips commit when JSONL is unchanged'
When run bash -c "grep -- 'diff --quiet' '$SCRIPT'"
The output should include 'diff --quiet'
End

It 'commits with a chore prefix'
When run bash -c "grep -- 'chore(beads)' '$SCRIPT'"
The output should include 'chore(beads)'
End

It 'pushes to origin main'
When run bash -c "grep 'push origin main' '$SCRIPT'"
The output should include 'push origin main'
End
End

End
