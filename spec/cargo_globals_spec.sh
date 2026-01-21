#!/usr/bin/env bash
# shellcheck disable=SC2329

Describe 'cargo-globals/install-cargo-globals.sh'
SCRIPT="$PWD/home-manager/modules/cargo-globals/install-cargo-globals.sh"

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

Describe 'configuration'
It 'reads from dotfiles/Cargo.toml'
When run bash -c "grep 'CARGO_TOML=' '$SCRIPT'"
The output should include 'dotfiles/Cargo.toml'
End
End

Describe 'tool checks'
It 'checks for cargo command'
When run bash -c "grep 'command -v cargo' '$SCRIPT'"
The output should include 'cargo'
End

It 'checks for dasel command'
When run bash -c "grep 'command -v dasel' '$SCRIPT'"
The output should include 'dasel'
End

It 'checks for jq command'
When run bash -c "grep 'command -v jq' '$SCRIPT'"
The output should include 'jq'
End
End

Describe 'file handling'
It 'exits gracefully when Cargo.toml is missing'
When run bash -c "grep -A 2 'if \[ ! -f' '$SCRIPT'"
The output should include 'exit 0'
End
End

Describe 'package installation'
It 'uses dasel to parse TOML'
When run bash -c "grep 'dasel' '$SCRIPT'"
The output should include 'dasel'
End

It 'supports table-style dependency versions'
When run bash -c "grep 'version // .value' '$SCRIPT'"
The output should include 'version // .value'
End

It 'uses cargo install with version'
When run bash -c "grep 'cargo install' '$SCRIPT'"
The output should include '--version'
End

It 'tries --locked flag first'
When run bash -c "grep -- '--locked' '$SCRIPT'"
The output should include '--locked'
End

It 'parses dependencies section'
When run bash -c "grep 'dependencies' '$SCRIPT'"
The output should include 'dependencies'
End

It 'builds an installed version map'
When run bash -c "grep 'INSTALLED_MAP' '$SCRIPT'"
The output should include 'INSTALLED_MAP'
End
End
End
