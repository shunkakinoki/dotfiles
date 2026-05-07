#!/usr/bin/env bash
# shellcheck disable=SC2329

Describe 'config/noctalia/default.nix bar widgets'
CONFIG="$PWD/config/noctalia/default.nix"

It 'places DarkMode immediately after Brightness on the right bar'
When run bash -c "awk '/widgets.right = \\[/{in_right=1} in_right && /id =/ { gsub(/.*id = \"|\";.*/, \"\"); print } in_right && /\\];/{exit}' '$CONFIG' | paste -sd ' ' -"
The output should include 'Brightness DarkMode ControlCenter'
End

End
