#!/usr/bin/env bash
# Brightness control with wob OSD feedback

WOBPIPE=/tmp/wobpipe

case "$1" in
raise)
  brightnessctl set 5%+
  ;;
lower)
  brightnessctl set 5%-
  ;;
*)
  echo "Usage: $0 {raise|lower}"
  exit 1
  ;;
esac

BRIGHTNESS=$(brightnessctl -m | awk -F, '{print substr($4, 0, length($4)-1)}')
echo "$BRIGHTNESS" >"$WOBPIPE"
