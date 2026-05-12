#!/usr/bin/env bash
# Inhibit Wayland idle when on AC power so noctalia's idle timeouts only fire on battery.
# Manages a wlinhibit process that holds an idle-inhibit Wayland surface.
set -euo pipefail

AC=/sys/class/power_supply/ACAD/online
INHIBIT_PID=""

cleanup() { [ -n "$INHIBIT_PID" ] && kill "$INHIBIT_PID" 2>/dev/null; }
trap cleanup EXIT

while true; do
  if [ "$(cat "$AC" 2>/dev/null)" = "1" ]; then
    if [ -z "$INHIBIT_PID" ] || ! kill -0 "$INHIBIT_PID" 2>/dev/null; then
      wlinhibit &
      INHIBIT_PID=$!
    fi
  else
    if [ -n "$INHIBIT_PID" ] && kill -0 "$INHIBIT_PID" 2>/dev/null; then
      kill "$INHIBIT_PID" 2>/dev/null
      INHIBIT_PID=""
    fi
  fi
  sleep 2
done
