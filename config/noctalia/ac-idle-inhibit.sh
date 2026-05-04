#!/usr/bin/env bash
# Inhibit idle when on AC power so noctalia's idle timeouts only fire on battery.
# Polls every 2s so AC state changes take effect well within the 5-min idle window.
set -euo pipefail

AC=/sys/class/power_supply/ACAD/online

while true; do
  if [ "$(cat "$AC" 2>/dev/null)" = "1" ]; then
    systemd-inhibit --what=idle --why="On AC power" --mode=block sleep 2
  else
    sleep 2
  fi
done
