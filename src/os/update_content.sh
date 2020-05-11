#!/bin/bash

cd "$(dirname "${BASH_SOURCE[0]}")" &&
    . "utils.sh"

main() {
    print_in_purple "\n   Update content\n\n"
    ask_for_confirmation "Do you want to update the content from the 'dotfiles' directory?"

    if answer_is_yes; then
        git fetch --all 1>/dev/null &&
            git reset --hard origin/master 1>/dev/null &&
            git clean -fd 1>/dev/null &&
            git submodule update --init --recursive 1>/dev/null
        print_result $? "Update content"
    fi
}

main
