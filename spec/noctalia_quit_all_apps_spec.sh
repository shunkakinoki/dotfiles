#!/usr/bin/env bash
# shellcheck disable=SC2016,SC2329

Describe 'config/noctalia/quit-all-apps.sh'
SCRIPT="$PWD/config/noctalia/quit-all-apps.sh"

It 'uses bash strict mode'
When run bash -c "head -5 '$SCRIPT'"
The output should include 'set -euo pipefail'
End

It 'closes all open windows via hyprctl'
When run bash -c "cat '$SCRIPT'"
The output should include 'hyprctl clients -j'
The output should include 'hyprctl dispatch closewindow'
End

End
