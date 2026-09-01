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

It 'runs the explicit foreground gateway command'
When run bash -c "grep -F 'gateway run --port 18789 --bind loopback' '$PWD/home-manager/services/openclaw/default.nix'"
The output should include 'gateway run --port 18789 --bind loopback'
End

It 'resolves the current k3s bridge address instead of pinning a pod subnet'
When run bash -c "grep -q 'ip -4 -o address show dev' '$PWD/home-manager/services/openclaw/k3s-proxy.sh' && grep -q 'bind=\${listen_address}' '$PWD/home-manager/services/openclaw/k3s-proxy.sh' && ! grep -R -q 'bind=10.42.0.1' '$PWD/home-manager/services/openclaw'"
The status should be success
End

It 'rate-limits process failures inside the k3s proxy unit'
When run bash -c "proxy=\$(sed -n '/k3sProxy = pkgs.writeShellApplication/,/};/p' '$PWD/home-manager/services/openclaw/default.nix'); unit=\$(sed -n '/systemd.user.services.openclaw-k3s-proxy =/,/Install = {/p' '$PWD/home-manager/services/openclaw/default.nix'); grep -q 'pkgs.coreutils' <<<\"\$proxy\" && grep -q 'Restart = \"on-failure\"' <<<\"\$unit\" && grep -q 'RestartSec = \"30s\"' <<<\"\$unit\" && grep -q 'StartLimitBurst = 3' <<<\"\$unit\""
The status should be success
End

It 'waits in one process until the k3s bridge address appears'
When run env SCRIPT="$PWD/home-manager/services/openclaw/k3s-proxy.sh" bash -c '
  tools="$(mktemp -d)"
  count_file="$tools/ip-count"
  printf "%s\n" "#!/usr/bin/env bash" "count=0" "[ ! -r \"$count_file\" ] || read -r count <\"$count_file\"" "count=\$((count + 1))" "printf \"%s\\n\" \"\$count\" >\"$count_file\"" "[ \"\$count\" -gt 1 ] || exit 1" "printf \"%s\\n\" \"2: cni0 inet 10.42.1.1/24 scope global cni0\"" >"$tools/ip"
  printf "%s\n" "#!/usr/bin/env bash" "exit 0" >"$tools/sleep"
  printf "%s\n" "#!/usr/bin/env bash" "printf \"%s\\n\" \"\$*\"" >"$tools/socat"
  chmod +x "$tools/ip" "$tools/sleep" "$tools/socat"
  PATH="$tools:$PATH" "$SCRIPT"
  status=$?
  rm -rf "$tools"
  exit "$status"
'
The stderr should include 'has no global IPv4 address; retrying every 30s'
The output should include 'TCP4-LISTEN:18789,bind=10.42.1.1,reuseaddr,fork'
The status should be success
End

It 'repeats missing bridge evidence every five minutes'
When run env SCRIPT="$PWD/home-manager/services/openclaw/k3s-proxy.sh" bash -c '
  tools="$(mktemp -d)"
  count_file="$tools/ip-count"
  stderr_file="$tools/stderr"
  printf "%s\n" "#!/usr/bin/env bash" "count=0" "[ ! -r \"$count_file\" ] || read -r count <\"$count_file\"" "count=\$((count + 1))" "printf \"%s\\n\" \"\$count\" >\"$count_file\"" "[ \"\$count\" -gt 11 ] || exit 1" "printf \"%s\\n\" \"2: cni0 inet 10.42.1.1/24 scope global cni0\"" >"$tools/ip"
  printf "%s\n" "#!/usr/bin/env bash" "exit 0" >"$tools/sleep"
  printf "%s\n" "#!/usr/bin/env bash" "exit 0" >"$tools/socat"
  chmod +x "$tools/ip" "$tools/sleep" "$tools/socat"
  PATH="$tools:$PATH" "$SCRIPT" 2>"$stderr_file"
  status=$?
  grep -c "has no global IPv4 address; retrying every 30s" "$stderr_file"
  rm -rf "$tools"
  exit "$status"
'
The output should equal '2'
The status should be success
End

It 'keeps the proxy and gateway on their shared fixed port'
When run env SCRIPT="$PWD/home-manager/services/openclaw/k3s-proxy.sh" OPENCLAW_K3S_PROXY_PORT=19999 bash -c '
  tools="$(mktemp -d)"
  printf "%s\n" "#!/usr/bin/env bash" "printf \"%s\\n\" \"2: cni0 inet 10.42.1.1/24 scope global cni0\"" >"$tools/ip"
  printf "%s\n" "#!/usr/bin/env bash" "printf \"%s\\n\" \"\$*\"" >"$tools/socat"
  chmod +x "$tools/ip" "$tools/socat"
  PATH="$tools:$PATH" "$SCRIPT"
  status=$?
  rm -rf "$tools"
  exit "$status"
'
The output should include 'TCP4-LISTEN:18789,bind=10.42.1.1,reuseaddr,fork'
The output should not include '19999'
The status should be success
End

It 'binds the proxy to the live cni0 address'
When run env SCRIPT="$PWD/home-manager/services/openclaw/k3s-proxy.sh" bash -c '
  tools="$(mktemp -d)"
  printf "%s\n" "#!/usr/bin/env bash" "printf \"%s\\n\" \"2: cni0 inet 10.42.1.1/24 scope global cni0\"" >"$tools/ip"
  printf "%s\n" "#!/usr/bin/env bash" "printf \"%s\\n\" \"\$*\"" >"$tools/socat"
  chmod +x "$tools/ip" "$tools/socat"
  PATH="$tools:$PATH" "$SCRIPT"
  status=$?
  rm -rf "$tools"
  exit "$status"
'
The output should include 'TCP4-LISTEN:18789,bind=10.42.1.1,reuseaddr,fork'
The output should not include 'bind=0.0.0.0'
The status should be success
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

It 'does not depend on an activation-created temporary log directory'
When run bash -c "grep '/tmp/hermes' '$SCRIPT'"
The status should be failure
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

It 'routes Hermes logs through systemd without a filesystem prerequisite'
When run bash -c "units=\$(sed -n '/systemd.user.services.hermes-gateway =/,/Install = {/p; /systemd.user.services.hermes-dashboard =/,/Install = {/p' '$PWD/home-manager/services/hermes/default.nix'); test \"\$(printf '%s' \"\$units\" | grep -cF 'StandardOutput = \"journal\";')\" -eq 2 && test \"\$(printf '%s' \"\$units\" | grep -cF 'StandardError = \"journal\";')\" -eq 2; printf '%s' \"\$units\""
The status should be success
The output should not include 'append:'
The output should not include '/tmp/hermes/'
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
The output should include 'listen 127.0.0.1:9120;'
The output should include 'proxy_pass http://127.0.0.1:9119;'
The output should include 'proxy_set_header Host 127.0.0.1;'
The output should include 'proxy_set_header Origin http://127.0.0.1;'
End
End
