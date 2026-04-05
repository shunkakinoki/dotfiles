#!/usr/bin/env bash
# shellcheck disable=SC2329

Describe 'cass/daily.sh'
SCRIPT="$PWD/home-manager/services/cass/daily.sh"

Describe 'script properties'
It 'uses strict mode'
When run bash -c "head -5 '$SCRIPT'"
The output should include 'set -euo pipefail'
End

It 'uses bash shebang'
When run bash -c "head -1 '$SCRIPT'"
The output should include '#!/usr/bin/env bash'
End
End

Describe 'cass commands'
It 'runs sources sync'
When run bash -c "cat '$SCRIPT'"
The output should include 'sources sync'
End

It 'runs analytics rebuild'
When run bash -c "cat '$SCRIPT'"
The output should include 'analytics rebuild'
End

It 'uses ~/.local/bin/cass path'
When run bash -c "cat '$SCRIPT'"
The output should include '.local/bin/cass'
End

It 'checks cass binary exists before running'
When run bash -c "cat '$SCRIPT'"
The output should include '! -x'
End
End

End
