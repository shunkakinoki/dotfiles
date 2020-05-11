#!/bin/bash

cd "$(dirname "${BASH_SOURCE[0]}")" || exit &&
    . "../../utils.sh" &&
    . "./utils.sh"

./homebrew.sh
