#!/bin/bash

cd "$(dirname "${BASH_SOURCE[0]}")" &&
    . "../../utils.sh" &&
    . "./utils.sh"

install_antibody() {
    curl -sfL git.io/antibody | sh -s - -b /usr/local/bin
}

install_starship() {
    curl -fsSL https://starship.rs/install.sh | bash
}

print_in_purple "\n   zsh\n\n"

install_package "zsh" "zsh"
install_package "fonts-powerline" "fonts-powerline"
install_package "fonts-firacode" "fonts-firacode"

install_antibody
install_starship

chsh -s "$USER" "$(which zsh)"
