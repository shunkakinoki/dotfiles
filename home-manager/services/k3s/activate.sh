#!/usr/bin/env bash
# Install the generated k3s service and sync kubeconfig for the current user.
# @diff@ and @systemctl@ are substituted by pkgs.replaceVars.
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
}

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
