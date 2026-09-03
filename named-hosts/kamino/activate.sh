#!/usr/bin/env bash
# Small activation phases keep identity checks before the write boundary.
set -euo pipefail

case "${1:?activation phase required}" in
check)
  name="${2:?name required}"
  identity="${3:?identity file required}"
  if [ "$(id -u)" != 0 ] || [ "$(cat /proc/1/comm)" != systemd ]; then
    echo "Kamino requires root on a systemd Linux machine." >&2
    exit 1
  fi
  if [ -f "$identity" ] && [ "$(cat "$identity")" != "$name" ]; then
    echo "Refusing to rename an installed Kamino machine." >&2
    exit 1
  fi
  ;;
prepare)
  mkdir -p /etc/sudoers.d
  ;;
user-manager)
  hostnamectl set-hostname "${2:?name required}"
  loginctl enable-linger root
  systemctl start user@0.service
  ;;
tailscale)
  name="${2:?name required}"
  tailscale_bin="${3:?tailscale binary required}"
  "$tailscale_bin" set --hostname="$name" --accept-dns=false --ssh=false
  echo "Tailscale installed. If not enrolled, run: tailscale up --hostname=$name --accept-dns=false --ssh=false"
  ;;
*)
  echo "Unknown Kamino activation phase" >&2
  exit 1
  ;;
esac
