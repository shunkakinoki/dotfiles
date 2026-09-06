#!/usr/bin/env bash
# Apply managed Tailscale flags using systemd-resolved for host DNS.
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

  echo "Restoring systemd-resolved stub resolv.conf for Tailscale DNS"
  run_root_cmd ln -sfn "$stub" "$resolv"
}

# Restore the resolved integration before enabling DNS acceptance. A stale
# direct resolv.conf can otherwise feed Tailscale its own resolver as upstream.
restore_resolved_stub
if [ "$#" -gt 0 ]; then
  "$TAILSCALE_BIN" up "$@"
else
  # Empty arguments leave enrollment to the host activation. Update only DNS,
  # preserving existing non-default preferences such as the node hostname.
  "$TAILSCALE_BIN" set --accept-dns=true
fi
