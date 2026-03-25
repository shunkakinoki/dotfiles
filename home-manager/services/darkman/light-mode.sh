#!/usr/bin/env bash
set -euo pipefail

dconf write /org/gnome/desktop/interface/color-scheme "'prefer-light'"
dconf write /org/gnome/desktop/interface/gtk-theme "'Adwaita'"
