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

Describe 'config generation'
It 'uses sed to substitute values in template'
When run bash -c "grep '@sed@' '$SCRIPT'"
The output should include '@sed@'
End

It 'substitutes DATABASE_MODE in template'
When run bash -c "grep '__DATABASE_MODE__' '$SCRIPT'"
The output should include 'DATABASE_MODE'
End

It 'substitutes DATABASE_CONNECTION_STRING in template'
When run bash -c "grep '__DATABASE_CONNECTION_STRING__' '$SCRIPT'"
The output should include 'DATABASE_CONNECTION_STRING'
End

It 'substitutes HOST in template'
When run bash -c "grep '__HOST__' '$SCRIPT'"
The output should include 'HOST'
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
