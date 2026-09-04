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
authorize-ssh)
  key_file="${2:?public key file required}"
  ssh_dir="${3:?SSH directory required}"
  ssh_keygen="${4:?ssh-keygen binary required}"
  key="$(cat "$key_file")"
  "$ssh_keygen" -lf "$key_file" >/dev/null
  mkdir -p "$ssh_dir"
  chmod 700 "$ssh_dir"
  touch "$ssh_dir/authorized_keys"
  chmod 600 "$ssh_dir/authorized_keys"
  chown root:root "$ssh_dir" "$ssh_dir/authorized_keys"
  if ! grep -qxF "$key" "$ssh_dir/authorized_keys"; then
    printf '\n%s\n' "$key" >>"$ssh_dir/authorized_keys"
  fi
  ;;
user-manager)
  hostnamectl set-hostname "${2:?name required}"
  loginctl enable-linger root
  systemctl start user@0.service
  ;;
tailscale)
  name="${2:?name required}"
  tailscale_bin="${3:?tailscale binary required}"
  shift 3
  "$tailscale_bin" up "$@"
  echo "Tailscale enrollment and preferences applied for $name."
  ;;
*)
  echo "Unknown Kamino activation phase" >&2
  exit 1
  ;;
esac
