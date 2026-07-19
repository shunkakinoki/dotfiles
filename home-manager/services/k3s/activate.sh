#!/usr/bin/env bash
# Install the generated k3s service and sync kubeconfig for the current user.
# Command placeholders are substituted by pkgs.replaceVars.
set -euo pipefail

SERVICE_FILE="$1"
KUBE_DIR="$2"
MOUNT_FILE="$3"
SYSTEM_SERVICE="/etc/systemd/system/k3s.service"
SYSTEM_MOUNT="/etc/systemd/system/var-lib-rancher-k3s-agent-containerd.mount"
MOUNT_POINT="/var/lib/rancher/k3s/agent/containerd"
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
if [ -f "$MOUNT_FILE" ] && ! @diff@ -q "$MOUNT_FILE" "$SYSTEM_MOUNT" >/dev/null 2>&1; then
  require_sudo || exit 0
  run_sudo cp -f "$MOUNT_FILE" "$SYSTEM_MOUNT"
  systemd_changed=1
fi

if [ -f "$SERVICE_FILE" ] && ! @diff@ -q "$SERVICE_FILE" "$SYSTEM_SERVICE" >/dev/null 2>&1; then
  require_sudo || exit 0
  run_sudo cp -f "$SERVICE_FILE" "$SYSTEM_SERVICE"
  systemd_changed=1
fi

if [ "$systemd_changed" -eq 1 ]; then
  run_sudo @systemctl@ daemon-reload
fi

if [ -f "$MOUNT_FILE" ]; then
  require_sudo || exit 0
  run_sudo mkdir -p "$MOUNT_POINT"
  run_sudo @systemctl@ enable --now var-lib-rancher-k3s-agent-containerd.mount
fi

run_sudo @systemctl@ enable --now k3s

if [ -f "$K3S_KUBECONFIG" ]; then
  run mkdir -p "$KUBE_DIR"
  require_sudo || exit 0
  run_sudo cp "$K3S_KUBECONFIG" "$KUBE_DIR/config"
  run_sudo chown "$(id -u):$(id -g)" "$KUBE_DIR/config"
  run chmod 600 "$KUBE_DIR/config"
fi
