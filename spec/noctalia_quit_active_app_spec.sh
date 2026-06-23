#!/usr/bin/env bash
# shellcheck disable=SC2016,SC2329

Describe 'config/noctalia/quit-active-app.sh'
SCRIPT="$PWD/config/noctalia/quit-active-app.sh"

It 'uses bash strict mode'
When run bash -c "head -5 '$SCRIPT'"
The output should include 'set -euo pipefail'
End

It 'queries the active window class via hyprctl'
When run bash -c "cat '$SCRIPT'"
The output should include 'hyprctl activewindow -j'
The output should include "jq -r '.class'"
End

It 'closes all windows matching the active class'
When run bash -c "cat '$SCRIPT'"
The output should include 'hyprctl clients -j'
The output should include 'hyprctl dispatch closewindow'
End

End
