#!/usr/bin/env bash
# Sync k3s config to /etc/rancher/k3s/ (requires sudo)
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

if [ -n "$SUDO_CMD" ]; then
  $SUDO_CMD mkdir -p /etc/rancher/k3s
  $SUDO_CMD cp "$HOME/.config/k3s/config.yaml" /etc/rancher/k3s/config.yaml
else
  echo "Warning: sudo not found, skipping k3s config installation" >&2
fi
