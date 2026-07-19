#!/usr/bin/env bash
# Install the generated k3s service and sync kubeconfig for the current user.
# Command placeholders are substituted by pkgs.replaceVars.
set -euo pipefail

SERVICE_FILE="$1"
KUBE_DIR="$2"
MOUNT_FILE="$3"
JOURNALD_FILE="$4"
HEALTH_SERVICE_FILE="$5"
HEALTH_TIMER_FILE="$6"
SMARTD_SERVICE_FILE="$7"
SYSTEM_SERVICE="/etc/systemd/system/k3s.service"
SYSTEM_MOUNT="/etc/systemd/system/var-lib-rancher-k3s-agent-containerd.mount"
SYSTEM_JOURNALD="/etc/systemd/journald.conf.d/10-kyber-limits.conf"
SYSTEM_HEALTH_SERVICE="/etc/systemd/system/kyber-host-health.service"
SYSTEM_HEALTH_TIMER="/etc/systemd/system/kyber-host-health.timer"
SYSTEM_SMARTD_SERVICE="/etc/systemd/system/kyber-smartd.service"
MOUNT_POINT="/var/lib/rancher/k3s/agent/containerd"
EXPECTED_CONTAINERD_UUID="90f29a7b-38ff-460b-b534-92a02f1412ec"
K3S_KUBECONFIG="/etc/rancher/k3s/k3s.yaml"

sudo_cmd=()
if command -v sudo >/dev/null 2>&1; then
  sudo_cmd=(sudo)
elif [ -x /run/wrappers/bin/sudo ]; then
  sudo_cmd=(/run/wrappers/bin/sudo)
elif [ -x /usr/bin/sudo ]; then
  sudo_cmd=(/usr/bin/sudo)
fi

run() {
  if [ -n "${DRY_RUN_CMD:-}" ]; then
    # shellcheck disable=SC2086
    $DRY_RUN_CMD "$@"
  else
    "$@"
  fi
}

run_sudo() {
  run "${sudo_cmd[@]}" "$@"
}

require_sudo() {
  if [ "${#sudo_cmd[@]}" -eq 0 ]; then
    echo "Warning: sudo not found, skipping k3s system setup" >&2
    return 1
  fi
  return 0
}

sync_root_file() {
  local source="$1"
  local target="$2"

  if [ ! -f "$source" ] || @diff@ -q "$source" "$target" >/dev/null 2>&1; then
    return 1
  fi

  require_sudo || return 1
  run_sudo mkdir -p "$(dirname "$target")"
  run_sudo cp -f "$source" "$target"
  return 0
}

configure_root_ext4_reserve() {
  local root_source root_fs_type filesystem_info block_count reserved_blocks target_reserved_blocks
  local target_reserved_percent=1

  root_source="$(@findmnt@ --noheadings --output SOURCE --target /)"
  root_fs_type="$(@findmnt@ --noheadings --output FSTYPE --target /)"

  if [ "$root_fs_type" != "ext4" ]; then
    return 0
  fi
  if [ ! -b "$root_source" ]; then
    echo "Warning: ext4 root source is not a block device: $root_source" >&2
    return 0
  fi

  require_sudo || return 0
  if ! filesystem_info="$(run_sudo @tune2fs@ -l "$root_source")"; then
    echo "Warning: unable to inspect ext4 reserve on $root_source" >&2
    return 0
  fi
  # shellcheck disable=SC2016
  block_count="$(@awk@ -F: '/^Block count:/ { gsub(/[[:space:]]/, "", $2); print $2 }' <<<"$filesystem_info")"
  # shellcheck disable=SC2016
  reserved_blocks="$(@awk@ -F: '/^Reserved block count:/ { gsub(/[[:space:]]/, "", $2); print $2 }' <<<"$filesystem_info")"
  if [ -z "$block_count" ] || [ -z "$reserved_blocks" ]; then
    echo "Warning: unable to inspect ext4 reserve on $root_source" >&2
    return 0
  fi

  target_reserved_blocks=$((block_count * target_reserved_percent / 100))
  if [ "$reserved_blocks" -eq "$target_reserved_blocks" ]; then
    return 0
  fi

  if ! run_sudo @tune2fs@ -m "$target_reserved_percent" "$root_source"; then
    echo "Warning: unable to configure ext4 reserve on $root_source" >&2
    return 0
  fi
  echo "Configured $root_source ext4 reserved blocks to ${target_reserved_percent}%"
}

configure_root_ext4_reserve

if @findmnt@ --mountpoint "$MOUNT_POINT" >/dev/null 2>&1; then
  mounted_source="$(@findmnt@ --noheadings --output SOURCE --target "$MOUNT_POINT")"
  mounted_uuid="$(@blkid@ --match-tag UUID --output value "$mounted_source")"
  if [ "$mounted_uuid" != "$EXPECTED_CONTAINERD_UUID" ]; then
    echo "Refusing to run k3s with unexpected containerd filesystem UUID: $mounted_uuid" >&2
    echo "Expected $EXPECTED_CONTAINERD_UUID at $MOUNT_POINT" >&2
    exit 1
  fi
fi

if [ -f "$MOUNT_FILE" ] && ! @findmnt@ --mountpoint "$MOUNT_POINT" >/dev/null 2>&1; then
  if @systemctl@ is-active --quiet k3s; then
    echo "Refusing to mount the containerd SSD while k3s is running" >&2
    echo "Run named-hosts/kyber/prepare-containerd-disk.sh before activating this configuration" >&2
    exit 1
  fi
  if [ -d "$MOUNT_POINT" ]; then
    require_sudo || exit 0
    if ! first_entry="$(run_sudo @find@ "$MOUNT_POINT" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null)"; then
      echo "Refusing to mount because $MOUNT_POINT could not be inspected" >&2
      exit 1
    fi
    if [ -n "$first_entry" ]; then
      echo "Refusing to hide a non-empty containerd directory at $MOUNT_POINT" >&2
      echo "Move or remove the old runtime only during an attended recovery" >&2
      exit 1
    fi
  fi
fi

systemd_changed=0
for systemd_file_pair in \
  "$MOUNT_FILE:$SYSTEM_MOUNT" \
  "$SERVICE_FILE:$SYSTEM_SERVICE" \
  "$HEALTH_SERVICE_FILE:$SYSTEM_HEALTH_SERVICE" \
  "$HEALTH_TIMER_FILE:$SYSTEM_HEALTH_TIMER" \
  "$SMARTD_SERVICE_FILE:$SYSTEM_SMARTD_SERVICE"; do
  source_file="${systemd_file_pair%%:*}"
  target_file="${systemd_file_pair#*:}"
  if sync_root_file "$source_file" "$target_file"; then
    systemd_changed=1
  fi
done

if [ "$systemd_changed" -eq 1 ]; then
  run_sudo @systemctl@ daemon-reload
fi

if sync_root_file "$JOURNALD_FILE" "$SYSTEM_JOURNALD"; then
  run_sudo @systemctl@ try-restart systemd-journald.service
fi

if [ -f "$MOUNT_FILE" ]; then
  require_sudo || exit 0
  run_sudo mkdir -p "$MOUNT_POINT"
  run_sudo @systemctl@ enable --now var-lib-rancher-k3s-agent-containerd.mount
fi

run_sudo @systemctl@ enable --now k3s

if [ -f "$SMARTD_SERVICE_FILE" ]; then
  run_sudo @systemctl@ enable --now kyber-smartd.service
fi

if [ -f "$HEALTH_TIMER_FILE" ]; then
  run_sudo @systemctl@ enable --now kyber-host-health.timer
fi

if [ -f "$K3S_KUBECONFIG" ]; then
  run mkdir -p "$KUBE_DIR"
  require_sudo || exit 0
  run_sudo cp "$K3S_KUBECONFIG" "$KUBE_DIR/config"
  run_sudo chown "$(id -u):$(id -g)" "$KUBE_DIR/config"
  run chmod 600 "$KUBE_DIR/config"
fi
