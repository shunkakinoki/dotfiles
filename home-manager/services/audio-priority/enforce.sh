#!/usr/bin/env bash

set -uo pipefail

switch_audio="@switchAudioBin@"
output_device="@outputDevice@"
input_device="@inputDevice@"

prefer() {
  local type="$1" device="$2"
  if [ "$("$switch_audio" -c -t "$type")" != "$device" ] &&
    "$switch_audio" -a -t "$type" | grep -qxF "$device"; then
    "$switch_audio" -t "$type" -s "$device"
  fi
}

# CoreAudio has no device-priority setting and emits no event the shell can
# subscribe to, so newly connected AirPods can only be overridden by polling.
while true; do
  prefer output "$output_device"
  prefer input "$input_device"
  sleep 2
done
