#!/usr/bin/env bash
# shellcheck disable=SC2329

Describe 'uv-globals/install-uv-globals.sh'
SCRIPT="$PWD/home-manager/modules/uv-globals/install-uv-globals.sh"

Describe 'systemd activation skip'
NIX_FILE="$PWD/home-manager/modules/uv-globals/default.nix"

It 'checks systemctl is-system-running to detect boot'
When run bash -c "grep 'is-system-running' '$NIX_FILE'"
The output should include 'is-system-running'
End

It 'skips install during system boot'
When run bash -c "grep -A 1 'is-system-running' '$NIX_FILE'"
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

It 'checks uv tool list for installed packages'
When run bash -c "grep 'uv tool list' '$SCRIPT'"
The output should include 'uv tool list'
End

It 'extracts package name from version spec'
When run bash -c "grep '><=!' '$SCRIPT'"
The output should include '><=!'
End

It 'extracts requested version from >= spec'
When run bash -c "grep 'req_version' '$SCRIPT'"
The output should include 'req_version'
End

It 'extracts installed version from uv tool list output'
When run bash -c "grep 'installed_version' '$SCRIPT'"
The output should include 'installed_version'
End

It 'skips install when version matches'
When run bash -c "grep 'already installed, skipping' '$SCRIPT'"
The output should include 'already installed, skipping'
End

It 'uses sort -V for version comparison instead of exact match'
When run bash -c "grep 'sort -V' '$SCRIPT'"
The output should include 'sort -V'
End

It 'skips when installed version is newer than required'
# Simulate: installed=0.15.9, required=0.15.8 -> should skip
When run bash -c "printf '0.15.8\n0.15.9\n' | sort -V | head -n1"
The output should eq '0.15.8'
End

It 'skips when installed version equals required'
# Simulate: installed=0.86.2, required=0.86.2 -> should skip
When run bash -c "printf '0.86.2\n0.86.2\n' | sort -V | head -n1"
The output should eq '0.86.2'
End

It 'detects when installed version is older than required'
# Simulate: installed=2.6.9, required=2.7.0 -> min is 2.6.9, not 2.7.0
When run bash -c "printf '2.7.0\n2.6.9\n' | sort -V | head -n1"
The output should eq '2.6.9'
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
