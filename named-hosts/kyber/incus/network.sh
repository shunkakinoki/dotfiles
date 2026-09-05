#!/usr/bin/env bash
set -euo pipefail

# Docker's FORWARD policy otherwise drops Incus egress. Permit only traffic
# from this bridge to the default uplink and its established return traffic.
uplink="$(ip -4 route show default | awk '/default/ { for (i=1; i<=NF; i++) if ($i == "dev") { print $(i+1); exit } }')"
if [ -z "$uplink" ] || [ "$uplink" = incus-crabbox ]; then
  echo "Cannot determine the Incus egress uplink." >&2
  exit 1
fi
iptables -w -S DOCKER-USER >/dev/null
if ! iptables -w -C DOCKER-USER -i incus-crabbox -o "$uplink" -j ACCEPT 2>/dev/null; then
  iptables -w -I DOCKER-USER -i incus-crabbox -o "$uplink" -j ACCEPT
fi
if ! iptables -w -C DOCKER-USER -i "$uplink" -o incus-crabbox -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT 2>/dev/null; then
  iptables -w -I DOCKER-USER -i "$uplink" -o incus-crabbox -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
fi
