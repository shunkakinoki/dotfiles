#!/usr/bin/env bash
# shellcheck disable=SC2329

Describe 'darkman scripts'

Describe 'dark-mode.sh'
DARK_SCRIPT="$PWD/home-manager/services/darkman/dark-mode.sh"

It 'has a bash shebang'
When run bash -c "head -1 '$DARK_SCRIPT'"
The output should include '#!/usr/bin/env bash'
End

It 'uses strict mode'
When run bash -c "grep 'set -euo pipefail' '$DARK_SCRIPT'"
The output should include 'set -euo pipefail'
End

It 'sets color-scheme to prefer-dark'
When run bash -c "cat '$DARK_SCRIPT'"
The output should include "prefer-dark"
End

It 'sets gtk-theme to Adwaita-dark'
When run bash -c "cat '$DARK_SCRIPT'"
The output should include "Adwaita-dark"
End

It 'uses dconf to write settings'
When run bash -c "grep -c 'dconf write' '$DARK_SCRIPT'"
The output should eq '2'
End
End

Describe 'light-mode.sh'
LIGHT_SCRIPT="$PWD/home-manager/services/darkman/light-mode.sh"

It 'has a bash shebang'
When run bash -c "head -1 '$LIGHT_SCRIPT'"
The output should include '#!/usr/bin/env bash'
End

It 'uses strict mode'
When run bash -c "grep 'set -euo pipefail' '$LIGHT_SCRIPT'"
The output should include 'set -euo pipefail'
End

It 'sets color-scheme to prefer-light'
When run bash -c "cat '$LIGHT_SCRIPT'"
The output should include "prefer-light"
End

It 'sets gtk-theme to Adwaita'
When run bash -c "cat '$LIGHT_SCRIPT'"
The output should include "Adwaita"
End

It 'uses dconf to write settings'
When run bash -c "grep -c 'dconf write' '$LIGHT_SCRIPT'"
The output should eq '2'
End
End

End
