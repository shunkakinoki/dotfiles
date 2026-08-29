#!/usr/bin/env bash
set -euo pipefail

readonly BRIDGE_INTERFACE="${OPENCLAW_K3S_BRIDGE_INTERFACE:-cni0}"
readonly LISTEN_PORT="${OPENCLAW_K3S_PROXY_PORT:-18789}"

listen_address="$(ip -4 -o address show dev "$BRIDGE_INTERFACE" scope global 2>/dev/null |
  awk 'NR == 1 { split($4, address, "/"); print address[1] }')"

if [ -z "$listen_address" ]; then
  echo "OpenClaw k3s proxy: $BRIDGE_INTERFACE has no global IPv4 address" >&2
  exit 75
fi

exec socat \
  "TCP4-LISTEN:${LISTEN_PORT},bind=${listen_address},reuseaddr,fork" \
  "TCP4:127.0.0.1:${LISTEN_PORT}"
