#!/usr/bin/env bash

set -uo pipefail

switch_audio="@switchAudioBin@"
output_device="@outputDevice@"
input_device="@inputDevice@"

# macOS hands the default route to AirPods a moment after they connect, so a
# device that took over within this many seconds of appearing is an
# auto-switch rather than a manual pick.
grace_seconds=10

declare -A seen_at=() last_current=()

prefer() {
  local type="$1" device="$2" devices current name previous
  devices=$("$switch_audio" -a -t "$type")
  current=$("$switch_audio" -c -t "$type")

  local -A connected=()
  while IFS= read -r name; do
    [ -n "$name" ] || continue
    connected["$name"]=1
    [ -n "${seen_at["$type|$name"]:-}" ] || seen_at["$type|$name"]=$SECONDS
  done <<<"$devices"
  for name in "${!seen_at[@]}"; do
    [ "${name%%|*}" = "$type" ] || continue
    [ -n "${connected["${name#*|}"]:-}" ] || unset 'seen_at[$name]'
  done

  previous="${last_current[$type]:-}"
  if [ "$current" != "$device" ] && [ -n "${connected["$device"]:-}" ]; then
    "$switch_audio" -t "$type" -s "$device"
    current="$device"
  elif [ -n "$previous" ] && [ "$current" != "$previous" ] &&
    [ -n "${connected["$previous"]:-}" ] &&
    [ $((SECONDS - ${seen_at["$type|$current"]:-0})) -le "$grace_seconds" ]; then
    "$switch_audio" -t "$type" -s "$previous"
    current="$previous"
  fi
  last_current["$type"]="$current"
}

# CoreAudio has no device-priority setting and emits no event the shell can
# subscribe to, so newly connected AirPods can only be overridden by polling.
while true; do
  prefer output "$output_device"
  prefer input "$input_device"
  sleep 2
done
