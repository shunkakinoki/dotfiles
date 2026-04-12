#!/usr/bin/env bash
# shellcheck disable=SC2329

Describe 'home-manager/programs/neovim/activate-copy-pack-lock.sh'
SCRIPT="$PWD/home-manager/programs/neovim/activate-copy-pack-lock.sh"

It 'uses bash shebang'
When run bash -c "head -1 '$SCRIPT'"
The output should include '#!/usr/bin/env bash'
End

It 'creates nvim config directory'
When run bash -c "grep 'mkdir -p' '$SCRIPT'"
The output should include '.config/nvim'
End

It 'copies pack-lock.json'
When run bash -c "grep 'cp -f' '$SCRIPT'"
The output should include 'nvim-pack-lock.json'
End

It 'sets readable permissions'
When run bash -c "grep 'chmod 644' '$SCRIPT'"
The output should include 'chmod 644'
End
End

Describe 'home-manager/programs/neovim/activate-build-plugins.sh'
SCRIPT="$PWD/home-manager/programs/neovim/activate-build-plugins.sh"

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
It 'searches for telescope-fzf-native.nvim directory'
When run bash -c "grep 'telescope-fzf-native' '$SCRIPT'"
The output should include 'telescope-fzf-native.nvim'
End

It 'builds with make'
When run bash -c "grep 'make -C' '$SCRIPT'"
The output should include 'make -C'
End
End

Describe 'fff.nvim binary download'
It 'downloads prebuilt binary from GitHub'
When run bash -c "grep 'fff.nvim' '$SCRIPT'"
The output should include 'fff.nvim'
End

It 'detects architecture'
When run bash -c "grep 'uname -m' '$SCRIPT'"
The output should include 'uname -m'
End

It 'uses curl for download'
When run bash -c "grep 'curl' '$SCRIPT'"
The output should include 'curl'
End
End

Describe 'vscode-diff build'
It 'searches for vscode-diff.nvim directory'
When run bash -c "grep 'vscode-diff' '$SCRIPT'"
The output should include 'vscode-diff.nvim'
End

It 'uses build.sh script'
When run bash -c "grep 'build.sh' '$SCRIPT'"
The output should include 'build.sh'
End
End

Describe 'activation wrapper quoting'
It 'quotes the pack lock source path'
When run cat "$PWD/home-manager/programs/neovim/default.nix"
The output should include '"${nvimPackLockJson}"'
End

It 'quotes the pack directory argument for plugin builds'
When run cat "$PWD/home-manager/programs/neovim/default.nix"
The output should include '"${packDir}" "${libExt}"'
End
End
End
