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
It 'enables on galactica and matic only'
When run bash -c "grep 'isGalactica || isMatic' '$PWD/home-manager/services/roborev/default.nix'"
The output should include 'isGalactica || isMatic'
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
End
