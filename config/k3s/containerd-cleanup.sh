#!/usr/bin/env bash
set -euo pipefail

crictl_bin=/var/lib/rancher/k3s/data/current/bin/crictl
runtime_endpoint=unix:///run/k3s/containerd/containerd.sock

if [ ! -x "$crictl_bin" ]; then
  echo "k3s crictl binary is unavailable: $crictl_bin" >&2
  exit 1
fi

echo "cleaning exited containerd containers"
exited_containers=$(timeout 10 "$crictl_bin" --runtime-endpoint "$runtime_endpoint" ps -a --state Exited -q)
while IFS= read -r container_id; do
  if [ -z "$container_id" ]; then
    continue
  fi
  echo "removing exited container: $container_id"
  timeout 10 "$crictl_bin" --runtime-endpoint "$runtime_endpoint" rm -f "$container_id" || true
done <<<"$exited_containers"

echo "cleaning not-ready containerd sandboxes"
not_ready_sandboxes=$(timeout 10 "$crictl_bin" --runtime-endpoint "$runtime_endpoint" pods --state NotReady -q)
while IFS= read -r sandbox_id; do
  if [ -z "$sandbox_id" ]; then
    continue
  fi
  echo "removing not-ready sandbox: $sandbox_id"
  timeout 10 "$crictl_bin" --runtime-endpoint "$runtime_endpoint" rmp -f "$sandbox_id" || true
done <<<"$not_ready_sandboxes"

echo "containerd cleanup complete"
