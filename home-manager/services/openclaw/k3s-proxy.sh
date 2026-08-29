#!/usr/bin/env bash
set -euo pipefail

readonly BRIDGE_INTERFACE="${OPENCLAW_K3S_BRIDGE_INTERFACE:-cni0}"
readonly LISTEN_PORT=18789
readonly ADDRESS_RETRY_SECONDS=30

resolve_listen_address() {
  local address

  if ! address="$(ip -4 -o address show dev "$BRIDGE_INTERFACE" scope global 2>/dev/null |
    awk 'NR == 1 { split($4, parts, "/"); print parts[1] }')"; then
    return 1
  fi
  [ -n "$address" ] || return 1
  printf '%s\n' "$address"
}

reported_missing_address=0
until listen_address="$(resolve_listen_address)"; do
  if [ "$reported_missing_address" -eq 0 ]; then
    printf 'OpenClaw k3s proxy: %s has no global IPv4 address; retrying every %ss\n' \
      "$BRIDGE_INTERFACE" "$ADDRESS_RETRY_SECONDS" >&2
    reported_missing_address=1
  fi
  sleep "$ADDRESS_RETRY_SECONDS"
done

exec socat \
  "TCP4-LISTEN:${LISTEN_PORT},bind=${listen_address},reuseaddr,fork" \
  "TCP4:127.0.0.1:${LISTEN_PORT}"
