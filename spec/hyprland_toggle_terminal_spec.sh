#!/usr/bin/env bash
# shellcheck disable=SC2329

Describe 'toggle-terminal.sh'
SCRIPT="$PWD/config/hyprland/scripts/toggle-terminal.sh"

Describe 'script structure'
It 'has a bash shebang'
When run bash -c "head -1 '$SCRIPT'"
The output should include '#!/usr/bin/env bash'
End

It 'uses ghostty-scratchpad class name'
When run bash -c "cat '$SCRIPT'"
The output should include 'ghostty-scratchpad'
End

It 'checks for existing client with hyprctl'
When run bash -c "cat '$SCRIPT'"
The output should include 'hyprctl clients'
End

It 'toggles scratchpad workspace'
When run bash -c "cat '$SCRIPT'"
The output should include 'togglespecialworkspace scratchpad'
End

It 'launches ghostty with custom class if not running'
When run bash -c "cat '$SCRIPT'"
The output should include 'ghostty --class'
End
End

End
