#!/usr/bin/env bash
# Keep host and managed user services responsive when an SSH session is busy,
# and stop a runaway user-space writer from starving the k3s control path.
set -euo pipefail

USER_UID="$(id -u)"
readonly USER_UID
readonly SYSTEM_DROP_IN_FILE="/etc/systemd/system/system.slice.d/10-kyber-managed-services.conf"
readonly USER_DROP_IN_FILE="/etc/systemd/system/user@${USER_UID}.service.d/10-kyber-managed-services.conf"
readonly USER_SLICE_DROP_IN_FILE="/etc/systemd/system/user.slice.d/10-kyber-io-ceiling.conf"
readonly BFQ_UDEV_RULE_FILE="/etc/udev/rules.d/60-kyber-bfq.rules"

# IOWeight only expresses a ratio for the block device. It cannot bound how
# fast user space dirties the shared ext4 journal, because jbd2 commits run in
# a root-cgroup kernel thread and every writer on the filesystem then blocks in
# jbd2_log_wait_for_space regardless of its slice.
USER_IO_WRITE_MAX="${KYBER_USER_IO_WRITE_MAX:-150M}"
readonly USER_IO_WRITE_MAX
readonly USER_IO_WRITE_PATH="/"

ROOT_CMD=()
if command -v sudo >/dev/null 2>&1; then
  ROOT_CMD=(sudo -n)
elif [ -x /run/wrappers/bin/sudo ]; then
  ROOT_CMD=(/run/wrappers/bin/sudo -n)
elif [ -x /usr/bin/sudo ]; then
  ROOT_CMD=(/usr/bin/sudo -n)
elif command -v doas >/dev/null 2>&1; then
  ROOT_CMD=(doas -n)
elif [ "$(id -u)" -ne 0 ]; then
  echo "Managed service priority requires root privileges." >&2
  exit 1
fi

run_root() {
  if [ "${#ROOT_CMD[@]}" -gt 0 ]; then
    "${ROOT_CMD[@]}" "$@"
  else
    "$@"
  fi
}

SYSTEM_CONTENT=$(
  cat <<'EOF'
[Slice]
CPUWeight=1000
IOWeight=1000
EOF
)
USER_CONTENT=$(
  cat <<'EOF'
[Service]
CPUWeight=1000
IOWeight=1000
EOF
)
USER_SLICE_CONTENT=$(
  printf '[Slice]\nIOWriteBandwidthMax=%s %s\n' "$USER_IO_WRITE_PATH" "$USER_IO_WRITE_MAX"
)
BFQ_UDEV_CONTENT=$(
  cat <<'EOF'
ACTION=="add|change", SUBSYSTEM=="block", KERNEL=="sd[a-z]", ATTR{queue/scheduler}="bfq"
EOF
)

changed=0
install_drop_in() {
  local drop_in_file="$1"
  local content="$2"

  if [ -f "$drop_in_file" ] && printf '%s\n' "$content" | cmp -s - "$drop_in_file"; then
    return
  fi

  echo "Installing managed service priority at $drop_in_file..."
  run_root mkdir -p "$(dirname "$drop_in_file")"
  printf '%s\n' "$content" | run_root tee "$drop_in_file" >/dev/null
  run_root chmod 0644 "$drop_in_file"
  changed=1
}

apply_runtime_weights() {
  local unit="$1"
  local cpu_weight io_weight

  cpu_weight="$(run_root systemctl show "$unit" --property CPUWeight --value)"
  io_weight="$(run_root systemctl show "$unit" --property IOWeight --value)"
  if [ "$cpu_weight" = 1000 ] && [ "$io_weight" = 1000 ]; then
    return
  fi

  run_root systemctl set-property --runtime "$unit" CPUWeight=1000 IOWeight=1000
}

apply_runtime_io_ceiling() {
  local current
  current="$(run_root systemctl show user.slice --property IOWriteBandwidthMax --value)"
  if [ "$current" = "$USER_IO_WRITE_PATH $USER_IO_WRITE_MAX" ]; then
    return
  fi

  run_root systemctl set-property --runtime user.slice \
    "IOWriteBandwidthMax=$USER_IO_WRITE_PATH $USER_IO_WRITE_MAX"
}

# cgroup io.weight is honoured only by BFQ or the iocost controller. Under
# mq-deadline every IOWeight= above is silently inert, which is how a user-slice
# backup job saturated the disk while k3s held a nominal 10:1 advantage.
select_bfq_scheduler() {
  local disk scheduler name

  run_root modprobe -q bfq >/dev/null 2>&1 || true

  for disk in /sys/block/sd[a-z]; do
    [ -e "$disk/queue/scheduler" ] || continue
    name="$(basename "$disk")"
    scheduler="$(cat "$disk/queue/scheduler")"

    case "$scheduler" in
    *"[bfq]"*)
      continue
      ;;
    *bfq*)
      echo "Selecting bfq on $name so IOWeight is enforced..."
      printf 'bfq\n' | run_root tee "$disk/queue/scheduler" >/dev/null
      ;;
    *)
      echo "bfq unavailable on $name; IOWeight stays inert there." >&2
      ;;
    esac
  done
}

install_drop_in "$SYSTEM_DROP_IN_FILE" "$SYSTEM_CONTENT"
install_drop_in "$USER_DROP_IN_FILE" "$USER_CONTENT"
install_drop_in "$USER_SLICE_DROP_IN_FILE" "$USER_SLICE_CONTENT"
if [ "$changed" -eq 1 ]; then
  run_root systemctl daemon-reload
fi

if [ ! -f "$BFQ_UDEV_RULE_FILE" ] || ! printf '%s\n' "$BFQ_UDEV_CONTENT" | cmp -s - "$BFQ_UDEV_RULE_FILE"; then
  echo "Installing bfq udev rule at $BFQ_UDEV_RULE_FILE..."
  run_root mkdir -p "$(dirname "$BFQ_UDEV_RULE_FILE")"
  printf '%s\n' "$BFQ_UDEV_CONTENT" | run_root tee "$BFQ_UDEV_RULE_FILE" >/dev/null
  run_root chmod 0644 "$BFQ_UDEV_RULE_FILE"
fi

select_bfq_scheduler

# Restarts would interrupt managed services. Apply the weights to the running
# slices only when needed; the drop-ins own subsequent boots and logins.
apply_runtime_weights system.slice
apply_runtime_weights "user@${USER_UID}.service"
apply_runtime_io_ceiling

echo "Host and managed user services have priority over interactive sessions."
echo "user.slice write ceiling: $USER_IO_WRITE_MAX on $USER_IO_WRITE_PATH"
