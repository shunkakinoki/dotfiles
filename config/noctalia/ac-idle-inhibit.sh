#!/usr/bin/env bash
# On battery: run swayidle for screen-off (5 min) and suspend (10 min).
# On AC: stop swayidle so only noctalia's lock fires.
set -euo pipefail

AC=/sys/class/power_supply/ACAD/online
SWAYIDLE_PID=""

cleanup() { [ -n "$SWAYIDLE_PID" ] && kill "$SWAYIDLE_PID" 2>/dev/null; }
trap cleanup EXIT

while true; do
  ON_AC="$(cat "$AC" 2>/dev/null)"

  if [ "$ON_AC" = "1" ]; then
    if [ -n "$SWAYIDLE_PID" ] && kill -0 "$SWAYIDLE_PID" 2>/dev/null; then
      kill "$SWAYIDLE_PID" 2>/dev/null
      SWAYIDLE_PID=""
      hyprctl dispatch dpms on
    fi
  else
    if [ -z "$SWAYIDLE_PID" ] || ! kill -0 "$SWAYIDLE_PID" 2>/dev/null; then
      swayidle -w \
        timeout 300 'hyprctl dispatch dpms off' \
        resume 'hyprctl dispatch dpms on' \
        timeout 600 'systemctl suspend' &
      SWAYIDLE_PID=$!
    fi
  fi
  sleep 2
done
