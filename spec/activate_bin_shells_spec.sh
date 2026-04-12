#!/usr/bin/env bash
# shellcheck disable=SC2329

Describe 'home-manager/modules/bin-shells/activate.sh'
SCRIPT="$PWD/home-manager/modules/bin-shells/activate.sh"

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

Describe 'NixOS detection'
It 'skips on NixOS systems'
When run bash -c "grep '/etc/NIXOS' '$SCRIPT'"
The output should include '/etc/NIXOS'
End
End

Describe 'sudo detection'
It 'checks for sudo command'
When run bash -c "grep 'command -v sudo' '$SCRIPT'"
The output should include 'command -v sudo'
End

It 'checks NixOS wrapper path'
When run bash -c "grep '/run/wrappers/bin/sudo' '$SCRIPT'"
The output should include '/run/wrappers/bin/sudo'
End
End

Describe 'shell symlinks'
It 'creates /bin/bash symlink'
When run bash -c "grep '/bin/bash' '$SCRIPT'"
The output should include '/bin/bash'
End

It 'creates /bin/fish symlink'
When run bash -c "grep '/bin/fish' '$SCRIPT'"
The output should include '/bin/fish'
End

It 'creates /bin/zsh symlink'
When run bash -c "grep '/bin/zsh' '$SCRIPT'"
The output should include '/bin/zsh'
End

It 'accepts shell paths as arguments'
When run bash -c "grep 'BASH_PATH' '$SCRIPT'"
The output should include 'BASH_PATH="$1"'
End
End
End
