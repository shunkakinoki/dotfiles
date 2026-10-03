#!/usr/bin/env bash
# shellcheck disable=SC2329,SC2016

Describe 'audio-priority/enforce.sh'
SCRIPT="$PWD/home-manager/services/audio-priority/enforce.sh"

setup() {
  WORK=$(mktemp -d)
  # Fake SwitchAudioSource: -c prints the current device, -a lists connected
  # devices for the current poll tick, and -s records the switch.
  cat >"$WORK/switch-audio" <<'STUB'
#!/usr/bin/env bash
type="" set_to="" mode=""
while [ "$#" -gt 0 ]; do
  case "$1" in
  -c) mode=current ;;
  -a) mode=all ;;
  -t) type="$2"; shift ;;
  -s) set_to="$2"; shift ;;
  esac
  shift
done
if [ -n "$set_to" ]; then
  printf '%s=%s\n' "$type" "$set_to" >>"$WORK/switched"
elif [ "$mode" = current ]; then
  cat "$WORK/ticks/$TICK/current-$type"
else
  cat "$WORK/ticks/$TICK/devices-$type"
fi
STUB
  chmod +x "$WORK/switch-audio"
  {
    printf '%s\n' 'set -uo pipefail'
    sed -n '/^switch_audio=/p; /^grace_seconds=/p; /^declare -A/p; /^prefer() {/,/^}/p' "$SCRIPT" |
      sed "s|@switchAudioBin@|$WORK/switch-audio|"
    printf '%s\n' 'for TICK in $(ls "$WORK/ticks" | sort -n); do'
    printf '%s\n' '  export TICK; SECONDS=$(cat "$WORK/ticks/$TICK/seconds")'
    printf '%s\n' '  prefer "$@"'
    printf '%s\n' 'done'
  } >"$WORK/prefer.sh"
  : >"$WORK/switched"
  export WORK
}

cleanup() {
  rm -rf "$WORK"
}

Before 'setup'
After 'cleanup'

# tick <n> <seconds> <current> <devices>
tick() {
  mkdir -p "$WORK/ticks/$1"
  printf '%s\n' "$2" >"$WORK/ticks/$1/seconds"
  printf '%s\n' "$3" >"$WORK/ticks/$1/current-output"
  printf '%s\n' "$4" >"$WORK/ticks/$1/devices-output"
}

use_devices() {
  tick 1 0 "$1" "$2"
}

It 'switches to the preferred device when it is connected but not current'
use_devices 'AirPods' "$(printf 'AirPods\nEarPods')"
When run bash "$WORK/prefer.sh" output EarPods
The status should be success
The contents of file "$WORK/switched" should equal 'output=EarPods'
End

It 'leaves the device alone when the preferred one is already current'
use_devices 'EarPods' "$(printf 'AirPods\nEarPods')"
When run bash "$WORK/prefer.sh" output EarPods
The contents of file "$WORK/switched" should equal ''
End

It 'leaves the device alone when the preferred one is not connected'
use_devices 'AirPods' "$(printf 'AirPods\nMacBook Speakers')"
When run bash "$WORK/prefer.sh" output EarPods
The contents of file "$WORK/switched" should equal ''
End

It 'matches whole device names only'
use_devices 'AirPods' 'EarPods Microphone'
When run bash "$WORK/prefer.sh" output EarPods
The contents of file "$WORK/switched" should equal ''
End

It 'reverts a newly connected device that grabs the default route'
tick 1 0 'MacBook Speakers' 'MacBook Speakers'
tick 2 100 'AirPods' "$(printf 'MacBook Speakers\nAirPods')"
When run bash "$WORK/prefer.sh" output EarPods
The contents of file "$WORK/switched" should equal 'output=MacBook Speakers'
End

It 'reverts when the route switches a tick after the device appears'
tick 1 0 'MacBook Speakers' 'MacBook Speakers'
tick 2 100 'MacBook Speakers' "$(printf 'MacBook Speakers\nAirPods')"
tick 3 102 'AirPods' "$(printf 'MacBook Speakers\nAirPods')"
When run bash "$WORK/prefer.sh" output EarPods
The contents of file "$WORK/switched" should equal 'output=MacBook Speakers'
End

It 'keeps a device picked manually after the grace window'
tick 1 0 'MacBook Speakers' 'MacBook Speakers'
tick 2 100 'MacBook Speakers' "$(printf 'MacBook Speakers\nAirPods')"
tick 3 200 'AirPods' "$(printf 'MacBook Speakers\nAirPods')"
When run bash "$WORK/prefer.sh" output EarPods
The contents of file "$WORK/switched" should equal ''
End

It 'keeps the new device when the previous one disconnected'
tick 1 0 'EarPods' 'EarPods'
tick 2 100 'AirPods' 'AirPods'
When run bash "$WORK/prefer.sh" output EarPods
The contents of file "$WORK/switched" should equal ''
End

It 'polls both output and input'
When run bash -c "grep -E '^  prefer (output|input) ' '$SCRIPT'"
The line 1 of output should include 'prefer output "$output_device"'
The line 2 of output should include 'prefer input "$input_device"'
End
End
