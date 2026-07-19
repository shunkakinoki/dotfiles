#!/usr/bin/env bash
# Install the generated k3s service and sync kubeconfig for the current user.
# Command placeholders are substituted by pkgs.replaceVars.
set -euo pipefail

SERVICE_FILE="$1"
KUBE_DIR="$2"
SYSTEM_SERVICE="/etc/systemd/system/k3s.service"
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

if [ -f "$SERVICE_FILE" ] && ! @diff@ -q "$SERVICE_FILE" "$SYSTEM_SERVICE" >/dev/null 2>&1; then
  require_sudo || exit 0
  run_sudo cp "$SERVICE_FILE" "$SYSTEM_SERVICE"
  run_sudo @systemctl@ daemon-reload
  run_sudo @systemctl@ enable --now k3s
fi

if [ -f "$K3S_KUBECONFIG" ]; then
  run mkdir -p "$KUBE_DIR"
  require_sudo || exit 0
  run_sudo cp "$K3S_KUBECONFIG" "$KUBE_DIR/config"
  run_sudo chown "$(id -u):$(id -g)" "$KUBE_DIR/config"
  run chmod 600 "$KUBE_DIR/config"
fi
