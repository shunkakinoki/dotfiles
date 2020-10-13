#!/bin/bash

cd "$(dirname "${BASH_SOURCE[0]}")" &&
    . "utils.sh"

main() {
    print_in_purple "\n   Update content\n\n"

    git fetch --all 1>/dev/null &&
        git reset --hard origin/main 1>/dev/null &&
        git clean -fd 1>/dev/null &&
        git submodule update --init --recursive 1>/dev/null
}

main
