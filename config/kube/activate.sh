#!/usr/bin/env bash
# Copy k3s kubeconfig to ~/.kube/config for non-root kubectl access
set -euo pipefail

K3S_KUBECONFIG="/etc/rancher/k3s/k3s.yaml"
KUBE_DIR="$HOME/.kube"

if [ ! -f "$K3S_KUBECONFIG" ]; then
  exit 0
fi

SUDO_CMD=""
if command -v sudo >/dev/null 2>&1; then
  SUDO_CMD="sudo"
elif [ -x /run/wrappers/bin/sudo ]; then
  SUDO_CMD="/run/wrappers/bin/sudo"
elif [ -x /usr/bin/sudo ]; then
  SUDO_CMD="/usr/bin/sudo"
fi

if [ -n "$SUDO_CMD" ]; then
  mkdir -p "$KUBE_DIR"
  $SUDO_CMD cp "$K3S_KUBECONFIG" "$KUBE_DIR/config"
  $SUDO_CMD chown "$(id -u):$(id -g)" "$KUBE_DIR/config"
  chmod 600 "$KUBE_DIR/config"
fi
