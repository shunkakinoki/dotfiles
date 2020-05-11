#!/bin/bash

cd "$(dirname "${BASH_SOURCE[0]}")" &&
    . "../../utils.sh" &&
    . "./utils.sh"

./auto.sh
./homebrew.sh
