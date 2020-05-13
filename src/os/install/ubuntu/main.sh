#!/bin/bash

cd "$(dirname "${BASH_SOURCE[0]}")" &&
    . "../../utils.sh" &&
    . "utils.sh"

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

update
upgrade

./build-essentials.sh

./git.sh
./image_tools.sh
./tmux.sh

./cleanup.sh
