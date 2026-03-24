#!/usr/bin/env bash
# shellcheck disable=SC2329

Describe 'scripts/build-neovim-plugins.sh'
SCRIPT="$PWD/scripts/build-neovim-plugins.sh"

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

Describe 'telescope-fzf-native build'
It 'searches for fzf-native in opt directory'
When run bash -c "cat '$SCRIPT'"
The output should include 'telescope-fzf-native.nvim'
End

It 'checks for libfzf.so'
When run bash -c "cat '$SCRIPT'"
The output should include 'libfzf.so'
End

It 'checks for libfzf.dylib'
When run bash -c "cat '$SCRIPT'"
The output should include 'libfzf.dylib'
End

It 'runs make to build'
When run bash -c "cat '$SCRIPT'"
The output should include 'make -C'
End
End
End
