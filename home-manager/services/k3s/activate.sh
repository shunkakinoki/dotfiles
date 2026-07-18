#!/usr/bin/env bash
# Install the generated k3s service and sync kubeconfig for the current user.
# @diff@ and @systemctl@ are substituted by pkgs.replaceVars.
set -euo pipefail

SERVICE_FILE="$1"
KUBE_DIR="$2"
CLEANUP_SERVICE_FILE="$3"
CLEANUP_TIMER_FILE="$4"
SYSTEM_SERVICE="/etc/systemd/system/k3s.service"
CLEANUP_SYSTEM_SERVICE="/etc/systemd/system/k3s-containerd-cleanup.service"
CLEANUP_SYSTEM_TIMER="/etc/systemd/system/k3s-containerd-cleanup.timer"
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
}

install_system_unit() {
  local source_file="$1"
  local destination_file="$2"

  if [ ! -f "$source_file" ] || @diff@ -q "$source_file" "$destination_file" >/dev/null 2>&1; then
    return 1
  fi
  require_sudo || return 1
  run_sudo cp "$source_file" "$destination_file"
}

if [ -f "$SERVICE_FILE" ] && ! @diff@ -q "$SERVICE_FILE" "$SYSTEM_SERVICE" >/dev/null 2>&1; then
  require_sudo || exit 0
  run_sudo cp "$SERVICE_FILE" "$SYSTEM_SERVICE"
  run_sudo @systemctl@ daemon-reload
  run_sudo @systemctl@ enable --now k3s
fi

units_changed=false
if install_system_unit "$CLEANUP_SERVICE_FILE" "$CLEANUP_SYSTEM_SERVICE"; then
  units_changed=true
fi
if install_system_unit "$CLEANUP_TIMER_FILE" "$CLEANUP_SYSTEM_TIMER"; then
  units_changed=true
fi
if [ "$units_changed" = true ]; then
  run_sudo @systemctl@ daemon-reload
fi
if [ -f "$CLEANUP_SYSTEM_TIMER" ] || [ -f "$CLEANUP_TIMER_FILE" ]; then
  require_sudo || exit 0
  run_sudo @systemctl@ enable --now k3s-containerd-cleanup.timer
fi

if [ -f "$K3S_KUBECONFIG" ]; then
  run mkdir -p "$KUBE_DIR"
  require_sudo || exit 0
  run_sudo cp "$K3S_KUBECONFIG" "$KUBE_DIR/config"
  run_sudo chown "$(id -u):$(id -g)" "$KUBE_DIR/config"
  run chmod 600 "$KUBE_DIR/config"
fi
