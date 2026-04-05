#!/usr/bin/env bash
# shellcheck disable=SC2329

Describe 'uv-globals/install-uv-globals.sh'
SCRIPT="$PWD/home-manager/modules/uv-globals/install-uv-globals.sh"

Describe 'systemd activation skip'
NIX_FILE="$PWD/home-manager/modules/uv-globals/default.nix"

It 'checks INVOCATION_ID to detect systemd service'
When run bash -c "grep 'INVOCATION_ID' '$NIX_FILE'"
The output should include 'INVOCATION_ID'
End

It 'skips install when running inside systemd'
When run bash -c "grep -A 1 'INVOCATION_ID' '$NIX_FILE'"
The output should include 'skipping uv globals install'
End
End

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

It 'checks for tomlq command'
When run bash -c "grep 'command -v tomlq' '$SCRIPT'"
The output should include 'tomlq'
End
End

Describe 'file handling'
It 'exits gracefully when pyproject.toml is missing'
When run bash -c "grep -A 2 'if \[ ! -f' '$SCRIPT'"
The output should include 'exit 0'
End
End

Describe 'offline skip'
It 'checks network connectivity before installing'
When run bash -c "grep 'timeout 3 bash' '$SCRIPT'"
The output should include 'timeout 3 bash'
End

It 'exits gracefully when offline'
When run bash -c "grep -A 2 'Network unavailable' '$SCRIPT'"
The output should include 'exit 0'
End
End

Describe 'tool installation'
It 'uses tomlq to parse TOML'
When run bash -c "grep 'tomlq' '$SCRIPT'"
The output should include 'tomlq'
End

It 'uses uv tool install'
When run bash -c "grep 'uv tool install' '$SCRIPT'"
The output should include 'uv tool install'
End

It 'uses --force flag for reinstall'
When run bash -c "grep -- '--force' '$SCRIPT'"
The output should include '--force'
End

It 'parses dependency-groups.tools'
When run bash -c "grep 'dependency-groups' '$SCRIPT'"
The output should include 'dependency-groups'
End

It 'parses requires-python version'
When run bash -c "grep 'requires-python' '$SCRIPT'"
The output should include 'requires-python'
End

It 'passes --python flag to uv tool install'
When run bash -c "grep -- '--python' '$SCRIPT'"
The output should include '--python'
End
End
End
