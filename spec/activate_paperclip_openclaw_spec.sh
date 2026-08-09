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

It 'restarts the gateway when Home Manager changes the unit'
When run bash -c "sed -n '/systemd.user.services.openclaw-gateway =/,/Install = {/p' '$PWD/home-manager/services/openclaw/default.nix' | grep -F 'X-SwitchMethod = \"restart\";'"
The output should include 'X-SwitchMethod = "restart";'
End

It 'restarts the bridge when Home Manager changes the unit'
When run bash -c "sed -n '/systemd.user.services.openclaw-k3s-proxy =/,/Install = {/p' '$PWD/home-manager/services/openclaw/default.nix' | grep -F 'X-SwitchMethod = \"restart\";'"
The output should include 'X-SwitchMethod = "restart";'
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

It 'builds the Hermes dashboard with optional native dependencies'
When run bash -c "grep -F -- '--include=optional --ignore-scripts=false' '$SCRIPT'"
The output should include 'install --workspace web --include=optional --ignore-scripts=false'
End

It 'builds the Hermes dashboard bundle during activation'
When run bash -c "grep -F -- 'run build --workspace web' '$SCRIPT'"
The output should include 'run build --workspace web'
End
End

Describe 'home-manager/services/hermes/default.nix'
It 'quotes the home directory argument when invoking the helper'
When run cat "$PWD/home-manager/services/hermes/default.nix"
The output should include '"${./activate.sh}" "${homeDir}"'
End

It 'passes the compatible Nix npm binary to the activation helper'
When run bash -c "grep -F 'nodejs_22' '$PWD/home-manager/services/hermes/default.nix'"
The output should include 'nodejs_22'
End

It 'serves the prebuilt dashboard without rebuilding under the service npm'
When run bash -c "grep -F -- '--skip-build' '$PWD/home-manager/services/hermes/default.nix'"
The output should include '--skip-build'
End

It 'restarts the dashboard when Home Manager changes the unit'
When run bash -c "sed -n '/systemd.user.services.hermes-dashboard =/,/Install = {/p' '$PWD/home-manager/services/hermes/default.nix' | grep -F 'X-SwitchMethod = \"restart\";'"
The output should include 'X-SwitchMethod = "restart";'
End

# The bridge moved from an inline socat invocation to nginx in #2302/#2306, so
# the listen/proxy pair now lives in hermes-dashboard-proxy.conf while the unit
# only references it. Assert both halves so the bridge stays verified.
It 'runs the bridge from the nginx proxy config'
When run bash -c "sed -n '/systemd.user.services.hermes-dashboard-proxy =/,/Install = {/p' '$PWD/home-manager/services/hermes/default.nix'"
The output should include 'nginx'
The output should include 'hermes-dashboard-proxy.conf'
The output should include 'X-SwitchMethod = "restart";'
End

It 'bridges the loopback dashboard to the Kubernetes host endpoint'
When run bash -c "cat '$PWD/home-manager/services/hermes/hermes-dashboard-proxy.conf'"
The output should include 'listen 172.17.0.1:9119;'
The output should include 'proxy_pass http://127.0.0.1:9119;'
End
End
