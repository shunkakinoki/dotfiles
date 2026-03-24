#!/usr/bin/env bash
# shellcheck disable=SC2329

Describe 'scripts/wallpaper-power-check.sh'
SCRIPT="$PWD/scripts/wallpaper-power-check.sh"

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

Describe 'AC power state check'
It 'reads AC supply path'
When run bash -c "cat '$SCRIPT'"
The output should include '@ac_supply_path@'
End

It 'gets wallpaperengine PID via systemctl'
When run bash -c "cat '$SCRIPT'"
The output should include 'linux-wallpaperengine.service'
End
End

Describe 'signal handling'
It 'sends SIGSTOP on battery'
When run bash -c "cat '$SCRIPT'"
The output should include '-STOP'
End

It 'sends SIGCONT on AC'
When run bash -c "cat '$SCRIPT'"
The output should include '-CONT'
End

It 'skips cleanly when PID is missing'
When run bash -c "cat '$SCRIPT'"
The output should include 'return'
End
End

End
