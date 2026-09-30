#!/usr/bin/env bash
# shellcheck disable=SC2329,SC2016

Describe 'audio-priority/enforce.sh'
SCRIPT="$PWD/home-manager/services/audio-priority/enforce.sh"

setup() {
  WORK=$(mktemp -d)
  # Fake SwitchAudioSource: -c prints the current device, -a lists connected
  # devices, and -s records the switch.
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
  cat "$WORK/current-$type"
else
  cat "$WORK/devices-$type"
fi
STUB
  chmod +x "$WORK/switch-audio"
  {
    printf '%s\n' 'set -uo pipefail'
    sed -n '/^switch_audio=/p; /^prefer() {/,/^}/p' "$SCRIPT" |
      sed "s|@switchAudioBin@|$WORK/switch-audio|"
    printf '%s\n' 'prefer "$@"'
  } >"$WORK/prefer.sh"
  : >"$WORK/switched"
  export WORK
}

cleanup() {
  rm -rf "$WORK"
}

Before 'setup'
After 'cleanup'

use_devices() {
  printf '%s\n' "$1" >"$WORK/current-output"
  printf '%s\n' "$2" >"$WORK/devices-output"
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

It 'polls both output and input'
When run bash -c "grep -E '^  prefer (output|input) ' '$SCRIPT'"
The line 1 of output should include 'prefer output "$output_device"'
The line 2 of output should include 'prefer input "$input_device"'
End
End
