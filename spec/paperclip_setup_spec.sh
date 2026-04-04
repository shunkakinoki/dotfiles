#!/usr/bin/env bash
# shellcheck disable=SC2329

Describe 'config/paperclip/setup.sh'
SCRIPT="$PWD/config/paperclip/setup.sh"

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

Describe 'config management'
It 'creates instance directory'
When run bash -c "grep 'mkdir -p' '$SCRIPT'"
The output should include 'INSTANCE_DIR'
End

It 'copies config file to instance directory'
When run bash -c "grep '@cp@' '$SCRIPT'"
The output should include 'config_file'
End

It 'sets restrictive permissions on config'
When run bash -c "grep 'chmod 600' '$SCRIPT'"
The output should include 'CONFIG'
End
End

Describe 'database provisioning'
It 'creates paperclip database on docker-postgres'
When run bash -c "grep 'createdb' '$SCRIPT'"
The output should include 'paperclip'
End

It 'checks if database already exists before creating'
When run bash -c "grep 'grep -qw paperclip' '$SCRIPT'"
The output should include 'paperclip'
End

It 'only runs on kyber'
When run bash -c "grep 'is_kyber' '$SCRIPT'"
The output should include 'is_kyber'
End
End

End
