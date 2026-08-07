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
It 'pins the managed Node versions'
When run cat "$PWD/home-manager/programs/fnm/default.nix"
The output should include '"24.14.0"'
The output should include '"22.21.1"'
The output should include '"20.19.0"'
End

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

It 'links the stable Node binary to the configured default version'
When run bash -c "grep 'node-versions/v\${DEFAULT_VERSION}' '$SCRIPT'"
The output should include 'DEFAULT_VERSION'
End
End

Describe 'activation wrapper quoting'
It 'quotes the fnm directory path'
When run cat "$PWD/home-manager/programs/fnm/default.nix"
The output should include '"${fnmDir}"'
End

It 'uses the macOS fnm directory on Darwin'
When run cat "$PWD/home-manager/programs/fnm/default.nix"
The output should include 'Library/Application Support/fnm'
End
End
End
