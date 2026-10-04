#!/usr/bin/env bash

set -uo pipefail

switch_audio="@switchAudioBin@"
output_device="@outputDevice@"
input_device="@inputDevice@"

prefer() {
  local type="$1" device="$2" devices current name
  devices=$("$switch_audio" -a -t "$type") || return 0
  current=$("$switch_audio" -c -t "$type") || return 0
  [ "$current" != "$device" ] || return 0

  while IFS= read -r name; do
    if [ "$name" = "$device" ]; then
      "$switch_audio" -t "$type" -s "$device"
      return
    fi
  done <<<"$devices"
}

# Prefer the configured wired devices while connected. Otherwise leave the
# selected route alone; connection timing cannot identify a manual selection.
while true; do
  prefer output "$output_device"
  prefer input "$input_device"
  sleep 2
done
