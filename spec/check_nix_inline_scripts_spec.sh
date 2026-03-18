#!/usr/bin/env bash
# shellcheck disable=SC2329

Describe 'scripts/check-nix-inline-scripts.sh'
SCRIPT="$PWD/scripts/check-nix-inline-scripts.sh"

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

Describe 'detection pattern'
It 'searches for writeScript patterns'
When run bash -c "grep 'write.*Script' '$SCRIPT'"
The output should include 'write'
End

It 'excludes .git directory'
When run bash -c "grep 'exclude-dir' '$SCRIPT'"
The output should include '.git'
End

It 'excludes .worktrees directory'
When run bash -c "grep 'exclude-dir' '$SCRIPT'"
The output should include '.worktrees'
End
End

End
