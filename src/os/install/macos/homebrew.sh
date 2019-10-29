#!/bin/bash

cd "$(dirname "${BASH_SOURCE[0]}")" &&
    . "../../utils.sh" &&
    . "./utils.sh"

get_homebrew_git_config_file_path() {
    local path=""

    if path="$(brew --repository 2>/dev/null)/.git/config"; then
        printf "%s" "$path"
        return 0
    else
        print_error "Homebrew (get config file path)"
        return 1
    fi
}

install_homebrew() {
    if ! cmd_exists "brew"; then
        printf "\n" | ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)" &>/dev/null
    fi

    print_result $? "Homebrew"
}

main() {
    print_in_purple "\n   Homebrew\n\n"

    install_homebrew

    brew_update
    brew_upgrade
}

main
