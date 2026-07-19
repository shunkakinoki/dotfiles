#!/usr/bin/env bash
set -euo pipefail

GALACTICA_AUTHORIZED_KEY="@galacticaAuthorizedKey@"

ensure_authorized_key() {
  local key="$1"
  local ssh_dir="$HOME/.ssh"
  local auth_file="$ssh_dir/authorized_keys"

  if [ -z "$key" ] || [[ $key == "@"*"@" ]]; then
    return 0
  fi

  mkdir -p "$ssh_dir"
  chmod 700 "$ssh_dir"
  touch "$auth_file"
  chmod 600 "$auth_file"

  if grep -qxF "$key" "$auth_file"; then
    return 0
  fi

  if [ -s "$auth_file" ] && [ "$(tail -c1 "$auth_file" | wc -l)" -eq 0 ]; then
    printf '\n' >>"$auth_file"
  fi
  printf '%s\n' "$key" >>"$auth_file"
  echo "k3s-server: authorized galactica SSH key for kubeconfig sync"
}

ensure_authorized_key "$GALACTICA_AUTHORIZED_KEY"

K3S_CONFIG_SOURCE="$HOME/.config/k3s/config.yaml"
KUBELET_CONFIG_SOURCE="$HOME/.config/k3s/kubelet.conf.d/10-kyber.conf"
KUBELET_CONFIG_TARGET="/var/lib/rancher/k3s/agent/etc/kubelet.conf.d/10-kyber.conf"

if [ ! -f "$K3S_CONFIG_SOURCE" ] || [ ! -f "$KUBELET_CONFIG_SOURCE" ]; then
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

$SUDO_CMD mkdir -p /etc/rancher/k3s "$(dirname "$KUBELET_CONFIG_TARGET")"

K3S_CONFIG_CHANGED=0
if ! diff -q "$K3S_CONFIG_SOURCE" /etc/rancher/k3s/config.yaml >/dev/null 2>&1; then
  $SUDO_CMD cp "$K3S_CONFIG_SOURCE" /etc/rancher/k3s/config.yaml
  K3S_CONFIG_CHANGED=1
fi

if ! diff -q "$KUBELET_CONFIG_SOURCE" "$KUBELET_CONFIG_TARGET" >/dev/null 2>&1; then
  $SUDO_CMD cp "$KUBELET_CONFIG_SOURCE" "$KUBELET_CONFIG_TARGET"
  K3S_CONFIG_CHANGED=1
fi

if [ "$K3S_CONFIG_CHANGED" -eq 1 ]; then
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
  $SUDO_CMD cat "$K3S_KUBECONFIG" |
    sed "s|https://127.0.0.1:6443|https://${TAILSCALE_DNS}:6443|g" \
      >"$REMOTE_KUBECONFIG"
  chmod 600 "$REMOTE_KUBECONFIG"
fi
