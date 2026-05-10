#!/usr/bin/env bash
# Generate a kubeconfig for remote access via Tailscale
set -euo pipefail

TAILSCALE_IP="100.72.158.65"
TAILSCALE_DNS="kyber.tail950b36.ts.net"
K3S_KUBECONFIG="/etc/rancher/k3s/k3s.yaml"
OUTPUT="${1:-$HOME/.kube/config-kyber-remote}"

if [ ! -f "$K3S_KUBECONFIG" ]; then
  echo "Error: $K3S_KUBECONFIG not found. Run on the k3s server." >&2
  exit 1
fi

SUDO_CMD=""
if [ "$(id -u)" -ne 0 ]; then
  SUDO_CMD="sudo"
fi

mkdir -p "$(dirname "$OUTPUT")"

$SUDO_CMD cat "$K3S_KUBECONFIG" \
  | sed "s|https://127.0.0.1:6443|https://${TAILSCALE_DNS}:6443|g" \
  | sed "s|default|kyber-remote|g" \
  > "$OUTPUT"

chmod 600 "$OUTPUT"

echo "Remote kubeconfig written to: $OUTPUT"
echo ""
echo "Usage on client machine:"
echo "  export KUBECONFIG=$OUTPUT"
echo "  kubectl get nodes"
echo ""
echo "Or merge with existing config:"
echo "  KUBECONFIG=~/.kube/config:$OUTPUT kubectl config view --flatten > ~/.kube/config-merged"
