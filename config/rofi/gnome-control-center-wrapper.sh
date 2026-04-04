#!/usr/bin/env bash
export XDG_CURRENT_DESKTOP=GNOME
export XDG_DATA_DIRS="@gnome_shell_schemas@:$XDG_DATA_DIRS"
exec @gnome_control_center@/bin/gnome-control-center "$@"
