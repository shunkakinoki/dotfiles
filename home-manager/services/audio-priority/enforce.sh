#!/usr/bin/env bash

set -uo pipefail

switch_audio="@switchAudioBin@"
device="@device@"

# CoreAudio has no device-priority setting and emits no event the shell can
# subscribe to, so newly connected AirPods can only be overridden by polling.
while true; do
  if [ "$("$switch_audio" -c -t output)" != "$device" ] &&
    "$switch_audio" -a -t output | grep -qxF "$device"; then
    "$switch_audio" -t output -s "$device"
  fi
  sleep 2
done
