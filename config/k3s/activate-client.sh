#!/usr/bin/env bash
set -euo pipefail

REMOTE_HOST="kyber.tail950b36.ts.net"
REMOTE_KUBECONFIG_PATH=".kube/config"
LOCAL_KUBECONFIG="$HOME/.kube/config-kyber"

if ! command -v tailscale >/dev/null 2>&1; then
  exit 0
fi

if ! tailscale status >/dev/null 2>&1; then
  exit 0
fi

mkdir -p "$HOME/.kube"

if scp -o ConnectTimeout=5 -o BatchMode=yes \
  "${REMOTE_HOST}:${REMOTE_KUBECONFIG_PATH}" "$LOCAL_KUBECONFIG" 2>/dev/null; then
  chmod 600 "$LOCAL_KUBECONFIG"
fi
