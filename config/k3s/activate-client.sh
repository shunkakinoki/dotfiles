#!/usr/bin/env bash
set -euo pipefail

KYBER_API_URL="@kyberApiUrl@"
KYBER_HOST="@kyberHost@"
KYBER_USER="@kyberUser@"
REMOTE_HOST="${KYBER_USER}@${KYBER_HOST}"
REMOTE_KUBECONFIG_PATH=".kube/config"
LOCAL_KUBECONFIG="$HOME/.kube/config-kyber"

if ! command -v tailscale >/dev/null 2>&1; then
  exit 0
fi

if ! tailscale status >/dev/null 2>&1; then
  exit 0
fi

mkdir -p "$HOME/.kube"

SCP_ERR=$(mktemp)
trap 'rm -f "$SCP_ERR"' EXIT

if scp -o ConnectTimeout=5 -o BatchMode=yes \
  "${REMOTE_HOST}:${REMOTE_KUBECONFIG_PATH}" "$LOCAL_KUBECONFIG" 2>"$SCP_ERR"; then
  chmod 600 "$LOCAL_KUBECONFIG"
  # Defense-in-depth: kyber's server activate rewrites the loopback URL,
  # but if the synced file still points at 127.0.0.1 (e.g. activate did
  # not run), force it to the Nix-managed cluster URL.
  sed -i.bak "s|https://127.0.0.1:6443|${KYBER_API_URL}|g" "$LOCAL_KUBECONFIG"
  rm -f "$LOCAL_KUBECONFIG.bak"
  echo "k3s-client: kubeconfig synced from ${REMOTE_HOST}"
else
  echo "k3s-client: failed to fetch kubeconfig from ${REMOTE_HOST}" >&2
  sed 's/^/k3s-client:   /' "$SCP_ERR" >&2
fi
