#!/usr/bin/env bash
# shellcheck disable=SC2329

Describe 'home-manager/services/dolt/start.sh'
SCRIPT="$PWD/home-manager/services/dolt/start.sh"

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
When run bash -c "sed 's|@[a-z_]*@|/usr|g' '$SCRIPT' | bash -n"
The status should be success
End
End

Describe 'placeholder substitutions'
It 'references @beadsDir@'
When run bash -c "grep '@beadsDir@' '$SCRIPT'"
The output should include '@beadsDir@'
End

It 'references @dolt@'
When run bash -c "grep '@dolt@' '$SCRIPT'"
The output should include '@dolt@'
End
End

Describe 'dolt migration behavior'
It 'migrates legacy dolt directory to df'
When run bash -c "grep 'mv -f' '$SCRIPT'"
The output should include 'mv -f'
End

It 'symlinks dolt to df for backwards compatibility'
When run bash -c "grep 'ln -sfn df' '$SCRIPT'"
The output should include 'ln -sfn df'
End

It 'refuses to overwrite an existing df directory'
When run bash -c "grep 'Refusing to migrate' '$SCRIPT'"
The output should include 'Refusing to migrate'
End
End

Describe 'sql-server invocation'
It 'binds to localhost'
When run bash -c "grep -- '-H 127.0.0.1' '$SCRIPT'"
The output should include '-H 127.0.0.1'
End

It 'listens on port 3307'
When run bash -c "grep -- '-P 3307' '$SCRIPT'"
The output should include '-P 3307'
End

It 'points --data-dir at the beads directory'
When run bash -c "grep -- '--data-dir' '$SCRIPT'"
The output should include '--data-dir'
End
End

End
