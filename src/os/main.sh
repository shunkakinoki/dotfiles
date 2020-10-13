#!/bin/bash

declare -r GITHUB_REPOSITORY="shunkakinoki/dotfiles"
declare -r DOTFILES_ORIGIN="git@github.com:$GITHUB_REPOSITORY.git"
declare -r DOTFILES_TARBALL_URL="https://github.com/$GITHUB_REPOSITORY/tarball/main"
declare -r DOTFILES_UTILS_URL="https://raw.githubusercontent.com/$GITHUB_REPOSITORY/main/src/os/utils.sh"
declare dotfilesDirectory="$HOME/dotfiles"
declare skipQuestions=false

verify_os() {
    declare -r MINIMUM_MACOS_VERSION="10.10"
    declare -r MINIMUM_UBUNTU_VERSION="18.04"
    local os_name
    local os_version
    os_name="$(get_os)"
    os_version="$(get_os_version)"
    if [ "$os_name" == "macos" ]; then
        if is_supported_version "$os_version" "$MINIMUM_MACOS_VERSION"; then
            return 0
        else
            printf "Sorry, this script is intended only for macOS %s+" "$MINIMUM_MACOS_VERSION"
        fi
    elif [ "$os_name" == "ubuntu" ]; then
        if is_supported_version "$os_version" "$MINIMUM_UBUNTU_VERSION"; then
            return 0
        else
            printf "Sorry, this script is intended only for Ubuntu %s+" "$MINIMUM_UBUNTU_VERSION"
        fi
    else
        printf "Sorry, this script is intended only for macOS and Ubuntu!"
    fi
    return 1
}

main() {
    cd "$(dirname "${BASH_SOURCE[0]}")" || exit 1
    if [ -x "utils.sh" ]; then
        . "utils.sh" || exit 1
    else
        download_utils || exit 1
    fi

    print_in_purple "\n   Starting shunkakinoki dotfiles\n\n"
    verify_os || exit 1

    skip_questions "$@" && skipQuestions=true
    ask_for_sudo

    ./update_content.sh
    ./create_symbolic_links.sh "$@"
    ./create_config_links.sh "$@"
    ./create_local_config_files.sh
    ./install/main.sh
    ./preferences/main.sh
}

main "$@"
