#!/usr/bin/env bash
set -euo pipefail

readonly EXPECTED_CONTAINERD_UUID="90f29a7b-38ff-460b-b534-92a02f1412ec"
readonly CONTAINERD_MOUNT="/var/lib/rancher/k3s/agent/containerd"
readonly STATE_DIR="/run/kyber-host-health"
readonly D_STATE_THRESHOLD=3
readonly D_STATE_SUSTAINED_SAMPLES=5
readonly IO_SOME_AVG300_THRESHOLD=20
readonly IO_FULL_AVG300_THRESHOLD=10
readonly IMAGEFS_USAGE_THRESHOLD=70
readonly CRI_LATENCY_THRESHOLD_SECONDS=5
readonly CRI_ERROR_THRESHOLD=5

install -d --mode 0755 "$STATE_DIR"

set_alert() {
  local key="$1"
  local message="$2"
  local marker="$STATE_DIR/${key}.alerted"

  if [ ! -e "$marker" ]; then
    kyber-host-alert "$key" "$message"
    : >"$marker"
  fi
}

clear_alert() {
  local key="$1"
  local marker="$STATE_DIR/${key}.alerted"

  if [ -e "$marker" ]; then
    logger --priority daemon.notice --tag kyber-host-health -- "$key recovered"
    rm -f "$marker"
  fi
}

check_io_pressure() {
  local some_avg300 full_avg300

  # shellcheck disable=SC2016
  some_avg300="$(awk '$1 == "some" { for (i = 1; i <= NF; i++) if ($i ~ /^avg300=/) { sub(/^avg300=/, "", $i); print $i } }' /proc/pressure/io)"
  # shellcheck disable=SC2016
  full_avg300="$(awk '$1 == "full" { for (i = 1; i <= NF; i++) if ($i ~ /^avg300=/) { sub(/^avg300=/, "", $i); print $i } }' /proc/pressure/io)"

  if awk -v some="$some_avg300" -v full="$full_avg300" -v some_limit="$IO_SOME_AVG300_THRESHOLD" -v full_limit="$IO_FULL_AVG300_THRESHOLD" 'BEGIN { exit !(some >= some_limit || full >= full_limit) }'; then
    set_alert "io-pressure" "sustained I/O PSI is elevated (some avg300=${some_avg300}, full avg300=${full_avg300})"
  else
    clear_alert "io-pressure"
  fi
}

check_d_state() {
  local count_file="$STATE_DIR/d-state.samples"
  local d_state_count previous_samples=0 samples=0

  d_state_count="$(ps --no-headers -eo stat= | awk '$1 ~ /^D/ { count++ } END { print count + 0 }')"
  if [ -r "$count_file" ]; then
    read -r previous_samples <"$count_file" || previous_samples=0
  fi

  if [ "$d_state_count" -ge "$D_STATE_THRESHOLD" ]; then
    samples=$((previous_samples + 1))
  fi
  printf '%s\n' "$samples" >"$count_file"

  if [ "$samples" -ge "$D_STATE_SUSTAINED_SAMPLES" ]; then
    set_alert "d-state" "${d_state_count} processes have remained in uninterruptible sleep for ${samples} consecutive samples"
  elif [ "$samples" -eq 0 ]; then
    clear_alert "d-state"
  fi
}

check_image_filesystem() {
  local mounted_source mounted_uuid usage_percent

  if ! findmnt --mountpoint "$CONTAINERD_MOUNT" >/dev/null 2>&1; then
    set_alert "image-filesystem" "$CONTAINERD_MOUNT is not mounted"
    return
  fi

  mounted_source="$(findmnt --noheadings --output SOURCE --target "$CONTAINERD_MOUNT")"
  mounted_uuid="$(blkid --match-tag UUID --output value "$mounted_source")"
  if [ "$mounted_uuid" != "$EXPECTED_CONTAINERD_UUID" ]; then
    set_alert "image-filesystem" "$CONTAINERD_MOUNT has UUID $mounted_uuid, expected $EXPECTED_CONTAINERD_UUID"
    return
  fi

  usage_percent="$(df --output=pcent "$CONTAINERD_MOUNT" | tail -n 1 | tr -cd '0-9')"
  if [ "$usage_percent" -ge "$IMAGEFS_USAGE_THRESHOLD" ]; then
    set_alert "image-filesystem" "containerd image filesystem usage is ${usage_percent}% (threshold ${IMAGEFS_USAGE_THRESHOLD}%)"
  else
    clear_alert "image-filesystem"
  fi
}

check_cri() {
  local started_at finished_at latency_seconds error_count

  started_at="$(date +%s)"
  if ! timeout 15 k3s crictl info >/dev/null 2>&1; then
    set_alert "cri-health" "k3s crictl info failed or exceeded 15 seconds"
    return
  fi
  finished_at="$(date +%s)"
  latency_seconds=$((finished_at - started_at))

  error_count="$(journalctl --unit k3s --since '5 minutes ago' --no-pager --quiet 2>/dev/null |
    grep -Eci 'DeadlineExceeded|deadline exceeded|FailedPrecondition|failed precondition|reserved (container )?name|failed to (create|stop|remove).*(sandbox|container)|cgroup.*(busy|failed)' || true)"

  if [ "$latency_seconds" -ge "$CRI_LATENCY_THRESHOLD_SECONDS" ] || [ "$error_count" -ge "$CRI_ERROR_THRESHOLD" ]; then
    set_alert "cri-health" "CRI latency was ${latency_seconds}s with ${error_count} lifecycle errors in the last five minutes"
  else
    clear_alert "cri-health"
  fi
}

check_io_pressure
check_d_state
check_image_filesystem
check_cri
