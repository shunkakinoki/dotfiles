#!/usr/bin/env bash
set -euo pipefail

if [ ! -f "$HOME/.config/k3s/config.yaml" ]; then
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

if [ -z "$SUDO_CMD" ]; then
  echo "Warning: sudo not found, skipping k3s config installation" >&2
  exit 0
fi

$SUDO_CMD mkdir -p /etc/rancher/k3s

if ! diff -q "$HOME/.config/k3s/config.yaml" /etc/rancher/k3s/config.yaml >/dev/null 2>&1; then
  $SUDO_CMD cp "$HOME/.config/k3s/config.yaml" /etc/rancher/k3s/config.yaml
  if systemctl is-active --quiet k3s; then
    $SUDO_CMD systemctl restart k3s
    echo "k3s restarted to apply config changes"
  fi
fi

K3S_KUBECONFIG="/etc/rancher/k3s/k3s.yaml"
REMOTE_KUBECONFIG="$HOME/.kube/config"
TAILSCALE_DNS="kyber.tail950b36.ts.net"

if [ -f "$K3S_KUBECONFIG" ]; then
  mkdir -p "$HOME/.kube"
  $SUDO_CMD cat "$K3S_KUBECONFIG" \
    | sed "s|https://127.0.0.1:6443|https://${TAILSCALE_DNS}:6443|g" \
    > "$REMOTE_KUBECONFIG"
  chmod 600 "$REMOTE_KUBECONFIG"
fi
