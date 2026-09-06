# shellcheck shell=bash
# ShellSpec fixtures intentionally contain literal shell/Nix expressions.
# shellcheck disable=SC2016
Describe 'home-manager/services/roborev/activate.sh'
SCRIPT="$PWD/home-manager/services/roborev/activate.sh"

It 'uses bash shebang'
When run bash -c "head -1 '$SCRIPT'"
The output should include '#!/usr/bin/env bash'
End

It 'creates the data directory'
When run bash -c "grep 'mkdir' '$SCRIPT'"
The output should include 'mkdir -p'
End

It 'sets restrictive permissions on data directory'
When run bash -c "grep 'chmod' '$SCRIPT'"
The output should include 'chmod 700'
End
End

Describe 'home-manager/services/roborev/start.sh'
SCRIPT="$PWD/home-manager/services/roborev/start.sh"

setup() {
  TEMP_HOME=$(mktemp -d)
  mkdir -p "$TEMP_HOME/dotfiles"
  printf 'CLIPROXY_API_KEY=test-key\n' >"$TEMP_HOME/dotfiles/.env"
  printf '#!/usr/bin/env bash\nprintf "%%s\\n" "$CLIPROXY_API_KEY" "$*"\n' >"$TEMP_HOME/roborev"
  chmod +x "$TEMP_HOME/roborev"
}

cleanup() {
  rm -rf "$TEMP_HOME"
}

Before 'setup'
After 'cleanup'

It 'loads the shared CLIProxy key before starting the daemon'
When run env -u CLIPROXY_API_KEY HOME="$TEMP_HOME" bash "$SCRIPT" "$TEMP_HOME/roborev" '127.0.0.1:7373'
The status should be success
The line 1 of output should equal 'test-key'
The line 2 of output should equal 'daemon run --addr 127.0.0.1:7373'
End
End

Describe 'home-manager/services/roborev/default.nix'
It 'enables on galactica, kyber, and matic'
When run bash -c "grep 'isGalactica || isKyber || isMatic' '$PWD/home-manager/services/roborev/default.nix'"
The output should include 'isGalactica || isKyber || isMatic'
End

It 'selects CI polling by host'
When run bash -c "grep 'ciEnabled = if inputs.host.isKyber then \"true\" else \"false\";' '$PWD/config/roborev/default.nix'"
The output should include 'ciEnabled = if inputs.host.isKyber then "true" else "false";'
End

It 'serializes Kyber review workers'
When run bash -c "grep 'maxWorkers = if inputs.host.isKyber then \"1\" else \"4\";' '$PWD/config/roborev/default.nix'"
The output should include 'maxWorkers = if inputs.host.isKyber then "1" else "4";'
End

It 'runs roborev daemon run'
When run bash -c "grep 'start.sh' '$PWD/home-manager/services/roborev/default.nix'"
The output should include 'start.sh'
End

It 'passes data dir to activate script'
When run cat "$PWD/home-manager/services/roborev/default.nix"
# shellcheck disable=SC2016
The output should include '"${./activate.sh}" "${dataDir}"'
End

It 'includes the Nix profile in the daemon PATH'
When run grep -F '/etc/profiles/per-user/${config.home.username}/bin' "$PWD/home-manager/services/roborev/default.nix"
The output should include '/etc/profiles/per-user/${config.home.username}/bin'
End

It 'includes Bun-installed agents in the launchd PATH'
When run grep -F 'PATH = "${homeDir}/.local/bin:${homeDir}/.bun/bin:' "$PWD/home-manager/services/roborev/default.nix"
The output should include '${homeDir}/.bun/bin'
End

It 'includes Bun-installed agents in the systemd PATH'
When run grep -F '"PATH=${homeDir}/.local/bin:${homeDir}/.bun/bin:' "$PWD/home-manager/services/roborev/default.nix"
The output should include '${homeDir}/.bun/bin'
End

It 'binds the daemon to the local host'
When run grep -F '127.0.0.1:7373' "$PWD/home-manager/services/roborev/default.nix"
The output should include '127.0.0.1:7373'
End

It 'bounds Kyber worker resources and restart behavior'
When run grep -E 'optionalAttrs isKyber|RestartSec = 5|StartLimitIntervalSec = 300|StartLimitBurst = 3|RestartSec = 30|TimeoutStopSec = 30|TasksMax = 2048|CPUQuota = "1600%"|MemoryHigh = "24G"|MemoryMax = "32G"' "$PWD/home-manager/services/roborev/default.nix"
The output should include 'optionalAttrs isKyber'
The output should include 'RestartSec = 5'
The output should include 'StartLimitIntervalSec = 300'
The output should include 'StartLimitBurst = 3'
The output should include 'RestartSec = 30'
The output should include 'TimeoutStopSec = 30'
The output should include 'TasksMax = 2048'
The output should include 'CPUQuota = "1600%"'
The output should include 'MemoryHigh = "24G"'
The output should include 'MemoryMax = "32G"'
End

It 'reclaims the Kyber daemon port from escaped RoboRev processes'
When run grep -F -- "-\${pkgs.procps}/bin/pkill -KILL -f '[r]oborev daemon run'" "$PWD/home-manager/services/roborev/default.nix"
The output should include "-\${pkgs.procps}/bin/pkill -KILL -f '[r]oborev daemon run'"
End
End

Describe 'shared RoboRev hooks'
It 'provides the local agent hook'
The path "$PWD/config/shared/hooks/roborev-agent.sh" should be exist
End

End
