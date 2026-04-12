#!/usr/bin/env bash
# shellcheck disable=SC2016,SC2329

Describe 'home-manager/modules/paperclip/activate.sh'
SCRIPT="$PWD/home-manager/modules/paperclip/activate.sh"

It 'uses bash shebang'
When run bash -c "head -1 '$SCRIPT'"
The output should include '#!/usr/bin/env bash'
End

It 'creates /tmp/paperclip'
When run bash -c "grep '/tmp/paperclip' '$SCRIPT'"
The output should include '/tmp/paperclip'
End

It 'creates .paperclip directory'
When run bash -c "grep '.paperclip' '$SCRIPT'"
The output should include '.paperclip'
End

It 'sets restrictive permissions'
When run bash -c "grep 'chmod 700' '$SCRIPT'"
The output should include 'chmod 700'
End
End

Describe 'home-manager/modules/paperclip/default.nix'
It 'quotes the home directory argument when invoking the helper'
When run cat "$PWD/home-manager/modules/paperclip/default.nix"
The output should include '"${./activate.sh}" "${homeDir}"'
End
End

Describe 'home-manager/modules/openclaw/activate.sh'
SCRIPT="$PWD/home-manager/modules/openclaw/activate.sh"

It 'uses bash shebang'
When run bash -c "head -1 '$SCRIPT'"
The output should include '#!/usr/bin/env bash'
End

It 'creates /tmp/openclaw'
When run bash -c "grep '/tmp/openclaw' '$SCRIPT'"
The output should include '/tmp/openclaw'
End

It 'creates .openclaw directory'
When run bash -c "grep '.openclaw' '$SCRIPT'"
The output should include '.openclaw'
End

It 'sets restrictive permissions'
When run bash -c "grep 'chmod 700' '$SCRIPT'"
The output should include 'chmod 700'
End
End

Describe 'home-manager/modules/openclaw/default.nix'
It 'quotes the home directory argument when invoking the helper'
When run cat "$PWD/home-manager/modules/openclaw/default.nix"
The output should include '"${./activate.sh}" "${homeDir}"'
End
End
