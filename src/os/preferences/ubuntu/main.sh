#!/bin/bash

cd "$(dirname "${BASH_SOURCE[0]}")" || exit

./privacy.sh
./terminal.sh
./ui_and_ux.sh
