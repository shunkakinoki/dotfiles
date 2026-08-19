#!/usr/bin/env bash
# Apply persisted Tailscale node flags and restore host DNS when MagicDNS
# is disabled. extraUpArgs are declared in Home Manager, but the system
# tailscaled unit never ran `tailscale up`, so CorpDNS could stay true
# across reboots and overwrite /etc/resolv.conf with a resolver that
# SERVFAILs when no upstreams are configured.
# Usage: activate-up.sh <tailscale_bin> [tailscale up args...]
set -euo pipefail

TAILSCALE_BIN="${1:?tailscale binary required}"
shift

SUDO_CMD=""
if [ "$(id -u)" -eq 0 ]; then
  SUDO_CMD=""
elif command -v sudo >/dev/null 2>&1; then
  SUDO_CMD="sudo"
elif [ -x /run/wrappers/bin/sudo ]; then
  SUDO_CMD="/run/wrappers/bin/sudo"
elif [ -x /usr/bin/sudo ]; then
  SUDO_CMD="/usr/bin/sudo"
elif command -v doas >/dev/null 2>&1; then
  SUDO_CMD="doas"
elif [ -x /usr/bin/doas ]; then
  SUDO_CMD="doas"
fi

run_root_cmd() {
  if [ -n "$SUDO_CMD" ]; then
    "$SUDO_CMD" "$@"
  else
    "$@"
  fi
}

restore_resolved_stub() {
  local stub="/run/systemd/resolve/stub-resolv.conf"
  local resolv="/etc/resolv.conf"
  local target=""

  if [ ! -e "$stub" ]; then
    return 0
  fi

  if [ -L "$resolv" ]; then
    target="$(readlink -f "$resolv" || true)"
    if [ "$target" = "$(readlink -f "$stub")" ]; then
      return 0
    fi
  fi

  echo "Restoring systemd-resolved stub resolv.conf (Tailscale MagicDNS disabled)"
  run_root_cmd ln -sfn "$stub" "$resolv"
}

accept_dns_false=false
for arg in "$@"; do
  if [ "$arg" = "--accept-dns=false" ]; then
    accept_dns_false=true
    break
  fi
done

up_status=0
if [ "$#" -gt 0 ]; then
  attempt=1
  while [ "$attempt" -le 5 ]; do
    if "$TAILSCALE_BIN" up "$@"; then
      up_status=0
      break
    fi
    up_status=$?
    echo "tailscale up failed (attempt ${attempt}/5, status ${up_status})" >&2
    attempt=$((attempt + 1))
    sleep 2
  done
fi

if [ "$accept_dns_false" = true ]; then
  "$TAILSCALE_BIN" set --accept-dns=false || true
  restore_resolved_stub
fi

exit "$up_status"
