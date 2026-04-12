#!/usr/bin/env bash
# Enable IP forwarding for Tailscale exit node (requires sudo/doas)
set -euo pipefail

SUDO_CMD=""
if command -v sudo >/dev/null 2>&1; then
  SUDO_CMD="sudo"
elif [ -x /run/wrappers/bin/sudo ]; then
  SUDO_CMD="/run/wrappers/bin/sudo"
elif [ -x /usr/bin/sudo ]; then
  SUDO_CMD="/usr/bin/sudo"
elif command -v doas >/dev/null 2>&1; then
  SUDO_CMD="doas"
elif [ -x /usr/bin/doas ]; then
  SUDO_CMD="/usr/bin/doas"
elif [ "$(id -u)" -ne 0 ]; then
  echo "IP forwarding requires root privileges, but sudo/doas is not available." >&2
  exit 1
fi

run_root_cmd() {
  if [ -n "$SUDO_CMD" ]; then
    "$SUDO_CMD" "$@"
  else
    "$@"
  fi
}

if [ "$(cat /proc/sys/net/ipv4/ip_forward)" != "1" ]; then
  echo "Enabling IP forwarding for Tailscale exit node..."
  run_root_cmd sysctl -w net.ipv4.ip_forward=1
  run_root_cmd sysctl -w net.ipv6.conf.all.forwarding=1
fi
if [ ! -f /etc/sysctl.d/99-tailscale.conf ]; then
  echo 'net.ipv4.ip_forward=1' | run_root_cmd tee /etc/sysctl.d/99-tailscale.conf
  echo 'net.ipv6.conf.all.forwarding=1' | run_root_cmd tee -a /etc/sysctl.d/99-tailscale.conf
fi
