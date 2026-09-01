#!/usr/bin/env bash
# shellcheck disable=SC2329

Describe 'Hyprland UWSM environment isolation'
MODULE="$PWD/config/hyprland/default.nix"

It 'removes the shell-wide library override before starting Hyprland'
When run bash -c "grep -F 'xdg.configFile.\"uwsm/env\".text' '$MODULE' && grep -F 'unset LD_LIBRARY_PATH' '$MODULE'"
The output should include 'xdg.configFile."uwsm/env".text'
The output should include 'unset LD_LIBRARY_PATH'
End

End
