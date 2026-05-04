#!/usr/bin/env bash
set -euo pipefail

AC=/sys/class/power_supply/ACAD/online

while true; do
    if [ "$(cat "$AC" 2>/dev/null)" = "1" ]; then
        systemd-inhibit --what=idle --why="On AC power" --mode=block sleep 20
    else
        sleep 20
    fi
done
