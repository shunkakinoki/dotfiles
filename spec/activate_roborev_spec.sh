# shellcheck shell=bash
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

Describe 'home-manager/services/roborev/default.nix'
It 'enables on galactica, kyber, and matic'
When run bash -c "grep 'isGalactica || isKyber || isMatic' '$PWD/home-manager/services/roborev/default.nix'"
The output should include 'isGalactica || isKyber || isMatic'
End

It 'runs roborev daemon run'
When run bash -c "grep 'daemon' '$PWD/home-manager/services/roborev/default.nix'"
The output should include '"daemon"'
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

It 'binds the daemon to the local host'
When run grep -F '127.0.0.1:7373' "$PWD/home-manager/services/roborev/default.nix"
The output should include '127.0.0.1:7373'
End
End

Describe 'shared RoboRev hooks'
It 'provides the local agent hook'
The path "$PWD/config/shared/hooks/roborev-agent.sh" should be exist
End

End
