#!/bin/bash

cd "$(dirname "${BASH_SOURCE[0]}")" || return

./close_system_preferences_panes.applescript

./dock.sh
