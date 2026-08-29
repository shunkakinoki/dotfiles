#!/usr/bin/env bash
set -euo pipefail

readonly EXPECTED_CONTAINERD_UUID="90f29a7b-38ff-460b-b534-92a02f1412ec"
readonly CONTAINERD_MOUNT="/var/lib/rancher/k3s/agent/containerd"
readonly STATE_DIR="${KYBER_HOST_HEALTH_STATE_DIR:-/run/kyber-host-health}"
readonly ORCHESTRATION_USER="${KYBER_ORCHESTRATION_USER:-ubuntu}"
readonly ORCHESTRATION_SLICE="orchestration.slice"
readonly ORCHESTRATION_RECOVERY_SAMPLES=5
readonly ORCHESTRATION_EVIDENCE_RETENTION=5
readonly D_STATE_THRESHOLD=3
readonly D_STATE_SUSTAINED_SAMPLES=5
readonly IO_SOME_AVG300_THRESHOLD=20
readonly IO_FULL_AVG300_THRESHOLD=10
readonly NODEFS_USAGE_THRESHOLD=70
readonly NODEFS_AVAILABLE_WARNING_GIB=200
readonly NODEFS_AVAILABLE_WARNING_BYTES=$((NODEFS_AVAILABLE_WARNING_GIB * 1024 * 1024 * 1024))
readonly NODEFS_KUBELET_RESERVE_GIB=50
readonly IMAGEFS_USAGE_THRESHOLD=70
readonly CRI_LATENCY_THRESHOLD_SECONDS=5
readonly CRI_ERROR_THRESHOLD=5
readonly DISK_WEAR_WARNING_PERCENT=10
readonly DISK_WEAR_CHECK_INTERVAL_SECONDS=21600

IO_PRESSURE_UNHEALTHY=0
D_STATE_UNHEALTHY=0
CRI_UNHEALTHY=0

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
    IO_PRESSURE_UNHEALTHY=1
    set_alert "io-pressure" "sustained I/O PSI is elevated (some avg300=${some_avg300}, full avg300=${full_avg300})"
  else
    IO_PRESSURE_UNHEALTHY=0
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
    D_STATE_UNHEALTHY=1
    set_alert "d-state" "${d_state_count} processes have remained in uninterruptible sleep for ${samples} consecutive samples"
  else
    D_STATE_UNHEALTHY=0
  fi
  if [ "$samples" -eq 0 ]; then
    clear_alert "d-state"
  fi
}

check_node_filesystem() {
  local available_bytes available_gib usage_percent

  if ! available_bytes="$(df --block-size=1 --output=avail / 2>/dev/null | tail -n 1 | tr -d '[:space:]')" ||
    [[ ! $available_bytes =~ ^[0-9]+$ ]]; then
    set_alert "node-filesystem" "unable to read available bytes on root nodefs"
    return
  fi

  if ! usage_percent="$(df --output=pcent / 2>/dev/null | tail -n 1 | tr -cd '0-9')" ||
    [[ ! $usage_percent =~ ^[0-9]+$ ]]; then
    set_alert "node-filesystem" "unable to read usage percentage on root nodefs"
    return
  fi

  available_gib=$((available_bytes / 1024 / 1024 / 1024))
  if [ "$usage_percent" -ge "$NODEFS_USAGE_THRESHOLD" ]; then
    set_alert "node-filesystem" "root nodefs usage is ${usage_percent}% (threshold ${NODEFS_USAGE_THRESHOLD}%) with ${available_gib} GiB available"
  elif [ "$available_bytes" -le "$NODEFS_AVAILABLE_WARNING_BYTES" ]; then
    set_alert "node-filesystem" "root nodefs has ${available_gib} GiB available (warning threshold ${NODEFS_AVAILABLE_WARNING_GIB} GiB, kubelet emergency reserve ${NODEFS_KUBELET_RESERVE_GIB} GiB)"
  else
    clear_alert "node-filesystem"
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

check_dns() {
  local resolv="/etc/resolv.conf"
  local nameservers=""

  if [ -r "$resolv" ] && grep -q 'generated by tailscale' "$resolv"; then
    set_alert "dns" "Tailscale overwrote /etc/resolv.conf; MagicDNS has no public upstreams and returns SERVFAIL"
    return
  fi

  if [ -r "$resolv" ]; then
    nameservers="$(awk '/^nameserver[[:space:]]/ { print $2 }' "$resolv")"
    if printf '%s\n' "$nameservers" | grep -qx '100.100.100.100' &&
      ! printf '%s\n' "$nameservers" | grep -Eqx '127\.0\.0\.53|1\.1\.1\.1|8\.8\.8\.8|8\.8\.4\.4|1\.0\.0\.1'; then
      set_alert "dns" "resolv.conf nameservers are MagicDNS-only; public name resolution will fail"
      return
    fi
  fi

  if ! getent hosts one.one.one.one >/dev/null 2>&1 && ! getent hosts github.com >/dev/null 2>&1; then
    set_alert "dns" "public DNS lookup failed"
    return
  fi

  clear_alert "dns"
}

check_cri() {
  local started_at finished_at latency_seconds error_count

  started_at="$(date +%s)"
  if ! timeout 15 k3s crictl info >/dev/null 2>&1; then
    CRI_UNHEALTHY=1
    set_alert "cri-health" "k3s crictl info failed or exceeded 15 seconds"
    return
  fi
  finished_at="$(date +%s)"
  latency_seconds=$((finished_at - started_at))

  error_count="$(journalctl --unit k3s --since '5 minutes ago' --no-pager --quiet 2>/dev/null |
    grep -Eci 'DeadlineExceeded|deadline exceeded|FailedPrecondition|failed precondition|reserved (container )?name|failed to (create|stop|remove).*(sandbox|container)|cgroup.*(busy|failed)' || true)"

  if [ "$latency_seconds" -ge "$CRI_LATENCY_THRESHOLD_SECONDS" ] || [ "$error_count" -ge "$CRI_ERROR_THRESHOLD" ]; then
    CRI_UNHEALTHY=1
    set_alert "cri-health" "CRI latency was ${latency_seconds}s with ${error_count} lifecycle errors in the last five minutes"
  else
    CRI_UNHEALTHY=0
    clear_alert "cri-health"
  fi
}

prune_orchestration_evidence() {
  local evidence_root="$STATE_DIR/evidence"
  local evidence_name evidence_path retained=0

  [ -d "$evidence_root" ] || return
  while IFS= read -r evidence_name; do
    [[ $evidence_name =~ ^[0-9]{8}T[0-9]{6}Z$ ]] || continue
    retained=$((retained + 1))
    if [ "$retained" -le "$ORCHESTRATION_EVIDENCE_RETENTION" ]; then
      continue
    fi

    evidence_path="$evidence_root/$evidence_name"
    [ -d "$evidence_path" ] || continue
    find "$evidence_path" -depth -delete
  done < <(
    for evidence_path in "$evidence_root"/*; do
      [ -d "$evidence_path" ] || continue
      basename "$evidence_path"
    done | sort -r
  )
}

capture_orchestration_evidence() {
  local evidence_dir evidence_root timestamp

  timestamp="$(date --utc +%Y%m%dT%H%M%SZ)"
  evidence_root="$STATE_DIR/evidence"
  evidence_dir="$evidence_root/$timestamp"
  install -d --mode 0700 "$evidence_root" "$evidence_dir"

  cat /proc/pressure/io >"$evidence_dir/io-pressure.txt"
  ps -eo state,pid,ppid,uid,unit,cgroup,wchan:32,comm,args >"$evidence_dir/processes.txt"
  pidstat -d -p ALL 1 1 >"$evidence_dir/process-io.txt" 2>&1 || true
  systemd-cgtop --batch --iterations=1 --depth=6 --order=io >"$evidence_dir/cgroup-io.txt" 2>&1 || true
  journalctl --unit k3s --since '10 minutes ago' --no-pager --quiet >"$evidence_dir/k3s-journal.txt" 2>&1 || true

  prune_orchestration_evidence
  printf '%s\n' "$evidence_dir"
}

orchestration_control() {
  local action="$1"
  local orchestration_uid

  orchestration_uid="$(id --user "$ORCHESTRATION_USER")"
  runuser --user "$ORCHESTRATION_USER" -- env \
    XDG_RUNTIME_DIR="/run/user/$orchestration_uid" \
    systemctl --user "$action" "$ORCHESTRATION_SLICE"
}

manage_orchestration_circuit_breaker() {
  local capture_file="$STATE_DIR/orchestration.capture"
  local frozen_file="$STATE_DIR/orchestration.frozen"
  local recovery_file="$STATE_DIR/orchestration.recovery-samples"
  local freeze_failure_alert="orchestration-freeze-failed"
  local state_failure_alert="orchestration-state-persist-failed"
  local thaw_failure_alert="orchestration-thaw-failed"
  local evidence_dir recovery_samples=0

  if [ "$IO_PRESSURE_UNHEALTHY" -eq 1 ] || [ "$D_STATE_UNHEALTHY" -eq 1 ]; then
    printf '0\n' >"$recovery_file"
    if [ ! -s "$capture_file" ]; then
      evidence_dir="$(capture_orchestration_evidence)"
      printf '%s\n' "$evidence_dir" >"$capture_file"
    else
      read -r evidence_dir <"$capture_file"
    fi

    if ! : >"$frozen_file"; then
      clear_alert "orchestration-circuit-breaker"
      set_alert "$state_failure_alert" "failed to persist frozen state for $ORCHESTRATION_SLICE; evidence: $evidence_dir"
    elif orchestration_control freeze; then
      clear_alert "$state_failure_alert"
      clear_alert "$freeze_failure_alert"
      clear_alert "$thaw_failure_alert"
      set_alert "orchestration-circuit-breaker" "froze $ORCHESTRATION_SLICE after sustained host I/O pressure; evidence: $evidence_dir"
    else
      rm -f "$frozen_file"
      clear_alert "orchestration-circuit-breaker"
      set_alert "$freeze_failure_alert" "failed to freeze $ORCHESTRATION_SLICE after sustained host I/O pressure; evidence: $evidence_dir"
    fi
    return
  fi

  if [ ! -e "$frozen_file" ]; then
    rm -f "$capture_file" "$recovery_file"
    clear_alert "orchestration-circuit-breaker"
    clear_alert "$state_failure_alert"
    clear_alert "$freeze_failure_alert"
    clear_alert "$thaw_failure_alert"
    return
  fi

  if [ "$CRI_UNHEALTHY" -eq 1 ]; then
    printf '0\n' >"$recovery_file"
    return
  fi

  if [ -r "$recovery_file" ]; then
    read -r recovery_samples <"$recovery_file" || recovery_samples=0
  fi
  recovery_samples=$((recovery_samples + 1))
  printf '%s\n' "$recovery_samples" >"$recovery_file"
  if [ "$recovery_samples" -lt "$ORCHESTRATION_RECOVERY_SAMPLES" ]; then
    return
  fi

  if orchestration_control thaw; then
    rm -f "$capture_file" "$frozen_file" "$recovery_file"
    clear_alert "orchestration-circuit-breaker"
    clear_alert "$state_failure_alert"
    clear_alert "$freeze_failure_alert"
    clear_alert "$thaw_failure_alert"
  else
    set_alert "$thaw_failure_alert" "failed to thaw $ORCHESTRATION_SLICE after $recovery_samples healthy samples"
  fi
}

check_disk_wear() {
  local stamp="$STATE_DIR/disk-wear.checked"
  local now last=0 disk name remaining

  now="$(date +%s)"
  if [ -r "$stamp" ]; then
    read -r last <"$stamp" || last=0
  fi
  if [ $((now - last)) -lt "$DISK_WEAR_CHECK_INTERVAL_SECONDS" ]; then
    return
  fi
  printf '%s\n' "$now" >"$stamp"

  for disk in /dev/sd[a-z]; do
    [ -b "$disk" ] || continue
    name="$(basename "$disk")"
    # Samsung publishes remaining write endurance as the normalized value of
    # Wear_Leveling_Count. smartd's -f only fires once that reaches the vendor
    # threshold of zero, which is after the rated endurance is already spent
    # and far too late to schedule a replacement.
    # shellcheck disable=SC2016
    remaining="$(smartctl -A "$disk" 2>/dev/null |
      awk '$2 == "Wear_Leveling_Count" { print $4 + 0; exit }')"
    if [ -z "$remaining" ]; then
      continue
    fi

    if [ "$remaining" -le "$DISK_WEAR_WARNING_PERCENT" ]; then
      set_alert "disk-wear-$name" "$name has ${remaining}% of its rated write endurance left; schedule a replacement before moving write-heavy state onto it"
    else
      clear_alert "disk-wear-$name"
    fi
  done
}

main() {
  install -d --mode 0755 "$STATE_DIR"
  check_io_pressure
  check_d_state
  check_node_filesystem
  check_image_filesystem
  check_disk_wear
  check_cri
  manage_orchestration_circuit_breaker
  check_dns
}

if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
  main "$@"
fi
