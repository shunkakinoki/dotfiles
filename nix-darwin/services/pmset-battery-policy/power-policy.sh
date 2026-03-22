#!/usr/bin/env bash
set -eu

pmset_bin="@pmsetBin@"
awk_bin="@awkBin@"
high_battery_threshold=@highBatteryThreshold@
high_battery_sleep_minutes=@highBatterySleepMinutes@
low_battery_sleep_minutes=@lowBatterySleepMinutes@

# Idle sleep timers do not override the hardware lid-close sleep path.
# shellcheck disable=SC2016
battery_percentage_awk='NR == 2 { if (match($0, /[0-9]+%/)) print substr($0, RSTART, RLENGTH - 1); exit }'
batteryPercentage="$($pmset_bin -g batt | $awk_bin "$battery_percentage_awk")"
batterySleepMinutes=$low_battery_sleep_minutes
batteryPowerNap=0

$pmset_bin -c sleep 0
$pmset_bin -c powernap 1

if [ -n "$batteryPercentage" ] && [ "$batteryPercentage" -ge "$high_battery_threshold" ]; then
  batterySleepMinutes=$high_battery_sleep_minutes
  batteryPowerNap=1
fi

$pmset_bin -b sleep "$batterySleepMinutes"
$pmset_bin -b powernap "$batteryPowerNap"
