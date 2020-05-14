#!/bin/bash

cd "$(dirname "${BASH_SOURCE[0]}")" &&
    . "../../utils.sh" &&
    . "utils.sh"

./deb.sh
./git.sh
./image_tools.sh
./plugins.sh
./tmux.sh
./zsh.sh

./cleanup.sh

update
upgrade
