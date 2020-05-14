#!/bin/bash

cd "$(dirname "${BASH_SOURCE[0]}")" &&
    . "../../utils.sh" &&
    . "utils.sh"

install_tmux_plugins() {
    ~/.tmux/plugins/tpm/scripts/install_plugins.sh
}

install_vim_plugins() {
    vim +'PlugInstall --sync' +qa
}

main() {
    print_in_purple "\n   Plugins\n\n"
    install_tmux_plugins
    install_vim_plugins
}

main
