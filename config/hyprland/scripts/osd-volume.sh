#!/usr/bin/env bash
# Volume control with wob OSD feedback

WOBPIPE=/tmp/wobpipe

get_volume() {
  wpctl get-volume @DEFAULT_AUDIO_SINK@ | awk '{print int($2 * 100)}'
}

get_mute() {
  wpctl get-volume @DEFAULT_AUDIO_SINK@ | grep -q MUTED && echo 1 || echo 0
}

case "$1" in
up)
  wpctl set-mute @DEFAULT_AUDIO_SINK@ 0
  wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%+
  ;;
down)
  wpctl set-mute @DEFAULT_AUDIO_SINK@ 0
  wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-
  ;;
mute)
  wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
  ;;
*)
  echo "Usage: $0 {up|down|mute}"
  exit 1
  ;;
esac

VOL=$(get_volume)
MUTED=$(get_mute)

if [ "$MUTED" = "1" ]; then
  echo 0 >"$WOBPIPE"
else
  echo "$VOL" >"$WOBPIPE"
fi
