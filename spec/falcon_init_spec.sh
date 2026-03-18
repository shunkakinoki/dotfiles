#!/usr/bin/env bash
# shellcheck disable=SC2329

Describe 'named-hosts/matic/falcon-init.sh'
SCRIPT="$PWD/named-hosts/matic/falcon-init.sh"

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

Describe 'placeholder substitutions'
It 'references @e2fsprogs@ for chattr'
When run bash -c "grep '@e2fsprogs@' '$SCRIPT'"
The output should include 'chattr'
End

It 'references @rsync@ for sync'
When run bash -c "grep '@rsync@' '$SCRIPT'"
The output should include 'rsync'
End

It 'references @falcon@ for falconctl'
When run bash -c "grep '@falcon@' '$SCRIPT'"
The output should include 'falconctl'
End
End

Describe 'logic'
It 'preserves falconstore from rsync deletion'
When run bash -c "grep 'falconstore' '$SCRIPT'"
The output should include '--exclude=falconstore'
End

It 'loads CID from env file'
When run bash -c "grep 'falcon-sensor.env' '$SCRIPT'"
The output should include '/etc/falcon-sensor.env'
End

It 'sets CID via falconctl'
When run bash -c "grep 'FALCON_CID' '$SCRIPT'"
The output should include 'FALCON_CID'
End
End

End
