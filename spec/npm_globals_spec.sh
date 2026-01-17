#!/usr/bin/env bash
# shellcheck disable=SC2329

Describe 'npm-globals/install-npm-globals.sh'
SCRIPT="$PWD/home-manager/modules/npm-globals/install-npm-globals.sh"

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
It 'reads from dotfiles/package.json'
When run bash -c "grep 'PACKAGE_JSON=' '$SCRIPT'"
The output should include 'dotfiles/package.json'
End
End

Describe 'tool checks'
It 'checks for bun command'
When run bash -c "grep 'command -v bun' '$SCRIPT'"
The output should include 'bun'
End

It 'checks for jq command'
When run bash -c "grep 'command -v jq' '$SCRIPT'"
The output should include 'jq'
End
End

Describe 'file handling'
It 'exits gracefully when package.json is missing'
When run bash -c "grep -A 2 'if \[ ! -f' '$SCRIPT'"
The output should include 'exit 0'
End
End

Describe 'package installation'
It 'reads trustedDependencies from package.json'
When run bash -c "grep 'trustedDependencies' '$SCRIPT'"
The output should include 'trustedDependencies'
End

It 'uses bun install --global'
When run bash -c "grep 'bun install --global' '$SCRIPT'"
The output should include 'bun install --global'
End

It 'parses dependencies with jq'
When run bash -c "grep 'dependencies' '$SCRIPT'"
The output should include 'dependencies'
End
End
End
