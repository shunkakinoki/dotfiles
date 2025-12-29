#!/usr/bin/env bash
# shellcheck disable=SC2329

Describe 'local-binaries/sync-local-binaries.sh'
SCRIPT="$PWD/home-manager/modules/local-binaries/sync-local-binaries.sh"

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

Describe 'configuration'
It 'reads from dotfiles/.local-binaries.txt'
When run bash -c "grep 'BINARIES_FILE=' '$SCRIPT'"
The output should include 'dotfiles/.local-binaries.txt'
End

It 'writes to ~/.local/bin'
When run bash -c "grep 'BIN_DIR=' '$SCRIPT'"
The output should include '.local/bin'
End
End

Describe 'file handling'
It 'exits gracefully when binaries file is missing'
When run bash -c "grep -A 2 'if \[ ! -f' '$SCRIPT'"
The output should include 'exit 0'
End

It 'creates bin directory if needed'
When run bash -c "grep 'mkdir -p' '$SCRIPT'"
The output should include 'mkdir -p'
End
End

Describe 'line processing'
It 'skips empty lines'
When run bash -c "grep -E '\\[ -z' '$SCRIPT'"
The output should include 'continue'
End

It 'skips comment lines'
When run bash -c "grep -A 2 'Skip comments' '$SCRIPT'"
The output should include 'continue'
End

It 'checks if binary exists and is executable'
When run bash -c "grep '\[ ! -f' '$SCRIPT'"
The output should include '! -x'
End
End

Describe 'symlink creation'
It 'uses basename for symlink name'
When run bash -c "grep 'basename' '$SCRIPT'"
The output should include 'basename'
End

It 'creates symlinks with ln -sf'
When run bash -c "grep 'ln -sf' '$SCRIPT'"
The output should include 'ln -sf'
End
End

End
