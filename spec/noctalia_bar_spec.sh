#!/usr/bin/env bash
# shellcheck disable=SC2329

Describe 'config/noctalia/default.nix bar widgets'
CONFIG="$PWD/config/noctalia/default.nix"

It 'places DarkMode immediately after Brightness on the right bar'
When run bash -c "awk '/widgets.right = \\[/{in_right=1} in_right && /id =/ { gsub(/.*id = \"|\";.*/, \"\"); print } in_right && /\\];/{exit}' '$CONFIG' | paste -sd ' ' -"
The output should include 'Brightness DarkMode ControlCenter'
End

It 'shows tray items inline instead of hiding them in the drawer'
When run bash -c "awk '/id = \"Tray\";/{in_tray=1} in_tray && /^          }/{exit} in_tray{print}' '$CONFIG'"
The output should include 'colorizeIcons = false;'
The output should include 'drawerEnabled = false;'
End

It 'keeps active window app icons uncolorized'
When run bash -c "awk '/id = \"ActiveWindow\";/{in_active_window=1} in_active_window && /^          }/{exit} in_active_window{print}' '$CONFIG'"
The output should include 'colorizeIcons = false;'
End

It 'does not duplicate the workspace widget on the left bar'
When run bash -c "awk '/widgets.left = \\[/{in_left=1} in_left && /id =/ {print} in_left && /^        \\];/{exit}' '$CONFIG'"
The output should not include 'Workspace'
End

It 'shows applications inside the centered numbered workspace widget'
When run bash -c "awk '/widgets.center = \\[/{in_center=1} in_center && /^        \\];/{exit} in_center{print}' '$CONFIG'"
The output should include 'labelMode = "index";'
The output should include 'showApplications = true;'
The output should include 'showApplicationsHover = false;'
The output should include 'showBadge = true;'
The output should include 'unfocusedIconsOpacity = 0.55;'
End

It 'keeps seconds visible in clock formats'
When run bash -c "awk '/id = \"Clock\";/{in_clock=1} in_clock && /^          }/{exit} in_clock{print}' '$CONFIG'"
The output should include 'formatHorizontal = "yyyy/MM/dd HH:mm:ss";'
The output should include 'formatVertical = "HH mm ss - dd MM";'
The output should include 'tooltipFormat = "yyyy/MM/dd HH:mm:ss";'
End

End
