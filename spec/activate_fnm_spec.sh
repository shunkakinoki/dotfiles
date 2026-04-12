#!/usr/bin/env bash
# shellcheck disable=SC2016,SC2329

Describe 'home-manager/programs/fnm/activate.sh'
SCRIPT="$PWD/home-manager/programs/fnm/activate.sh"

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

Describe 'node version management'
It 'accepts fnm binary path as argument'
When run bash -c "grep 'FNM_BIN' '$SCRIPT'"
The output should include 'FNM_BIN="$1"'
End

It 'accepts fnm directory as argument'
When run bash -c "grep 'FNM_DIR' '$SCRIPT'"
The output should include 'FNM_DIR="$2"'
End

It 'accepts default version as argument'
When run bash -c "grep 'DEFAULT_VERSION' '$SCRIPT'"
The output should include 'DEFAULT_VERSION="$3"'
End

It 'installs node versions'
When run bash -c "grep 'install' '$SCRIPT'"
The output should include 'install'
End

It 'sets default version'
When run bash -c "grep 'fnm.*default' '$SCRIPT'"
The output should include 'default'
End

It 'creates stable symlink for systemd'
When run bash -c "grep 'ln -sf' '$SCRIPT'"
The output should include '.local/bin/node'
End
End
End
