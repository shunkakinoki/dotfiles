#!/usr/bin/env bash
# shellcheck disable=SC2329

Describe 'uv-globals/install-uv-globals.sh'
SCRIPT="$PWD/home-manager/modules/uv-globals/install-uv-globals.sh"

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
It 'reads from dotfiles/pyproject.toml'
When run bash -c "grep 'PYPROJECT=' '$SCRIPT'"
The output should include 'dotfiles/pyproject.toml'
End
End

Describe 'tool checks'
It 'checks for uv command'
When run bash -c "grep 'command -v uv' '$SCRIPT'"
The output should include 'uv'
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
It 'exits gracefully when pyproject.toml is missing'
When run bash -c "grep -A 2 'if \[ ! -f' '$SCRIPT'"
The output should include 'exit 0'
End
End

Describe 'tool installation'
It 'uses dasel to parse TOML'
When run bash -c "grep 'dasel' '$SCRIPT'"
The output should include 'dasel'
End

It 'uses uv tool install'
When run bash -c "grep 'uv tool install' '$SCRIPT'"
The output should include 'uv tool install'
End

It 'uses --force flag for reinstall'
When run bash -c "grep -- '--force' '$SCRIPT'"
The output should include '--force'
End

It 'parses project.dependencies'
When run bash -c "grep 'project.dependencies' '$SCRIPT'"
The output should include 'project.dependencies'
End
End
End
