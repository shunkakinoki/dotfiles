#!/usr/bin/env bash
# shellcheck disable=SC2016,SC2329

Describe 'home-manager/services/openclaw/activate.sh'
SCRIPT="$PWD/home-manager/services/openclaw/activate.sh"

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

Describe 'home-manager/services/openclaw/default.nix'
It 'quotes the home directory argument when invoking the helper'
When run cat "$PWD/home-manager/services/openclaw/default.nix"
The output should include '"${./activate.sh}" "${homeDir}"'
End

It 'forces loopback bind on the gateway unit'
When run bash -c "grep -- '--bind loopback' '$PWD/home-manager/services/openclaw/default.nix'"
The output should include '--bind loopback'
End

It 'proxies the loopback gateway only through the k3s bridge'
When run bash -c "grep -F 'TCP4-LISTEN:18789,bind=10.42.0.1' '$PWD/home-manager/services/openclaw/default.nix'"
The output should include 'TCP4-LISTEN:18789,bind=10.42.0.1'
The output should not include 'bind=0.0.0.0'
End

It 'orders the k3s bridge proxy after the loopback gateway'
When run bash -c "grep -F 'After = [ \"openclaw-gateway.service\" ]' '$PWD/home-manager/services/openclaw/default.nix'"
The output should include 'openclaw-gateway.service'
End

It 'restarts the gateway and bridge when Home Manager changes the units'
When run grep -c 'X-RestartIfChanged' "$PWD/home-manager/services/openclaw/default.nix"
The output should equal 2
End
End

Describe 'home-manager/services/hermes/activate.sh'
SCRIPT="$PWD/home-manager/services/hermes/activate.sh"

It 'uses bash shebang'
When run bash -c "head -1 '$SCRIPT'"
The output should include '#!/usr/bin/env bash'
End

It 'creates /tmp/hermes'
When run bash -c "grep '/tmp/hermes' '$SCRIPT'"
The output should include '/tmp/hermes'
End

It 'creates .hermes directory'
When run bash -c "grep '.hermes' '$SCRIPT'"
The output should include '.hermes'
End

It 'sets restrictive permissions'
When run bash -c "grep 'chmod 700' '$SCRIPT'"
The output should include 'chmod 700'
End
End

Describe 'home-manager/services/hermes/default.nix'
It 'quotes the home directory argument when invoking the helper'
When run cat "$PWD/home-manager/services/hermes/default.nix"
The output should include '"${./activate.sh}" "${homeDir}"'
End
End
