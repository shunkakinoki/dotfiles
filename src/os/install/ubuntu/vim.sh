#!/bin/bash

cd "$(dirname "${BASH_SOURCE[0]}")" &&
    . "./utils.sh"

print_in_purple "\n   vim\n\n"

install_package "GNOME Vim" "vim-gnome"
