#!/usr/bin/env bash
set -euo pipefail

CHAIN="kyber-firewall"
PUBLIC_IF="eno1"

SUDO_CMD=""
if command -v sudo >/dev/null 2>&1; then
  SUDO_CMD="sudo"
elif [ -x /run/wrappers/bin/sudo ]; then
  SUDO_CMD="/run/wrappers/bin/sudo"
elif [ -x /usr/bin/sudo ]; then
  SUDO_CMD="/usr/bin/sudo"
elif command -v doas >/dev/null 2>&1; then
  SUDO_CMD="doas"
elif [ "$(id -u)" -ne 0 ]; then
  echo "Firewall setup requires root privileges." >&2
  exit 1
fi

run_root() {
  if [ -n "$SUDO_CMD" ]; then
    "$SUDO_CMD" "$@"
  else
    "$@"
  fi
}

ipt() {
  run_root @iptables@ "$@"
}

if ipt -L "$CHAIN" -n >/dev/null 2>&1; then
  echo "Firewall chain $CHAIN already exists, skipping."
  exit 0
fi

echo "Configuring iptables firewall on $PUBLIC_IF..."

ipt -N "$CHAIN"

# Allow established/related connections
ipt -A "$CHAIN" -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# Allow SSH
ipt -A "$CHAIN" -p tcp --dport 22 -j ACCEPT

# Drop everything else on public interface
ipt -A "$CHAIN" -j DROP

# Insert chain into INPUT for public interface only
ipt -I INPUT 1 -i "$PUBLIC_IF" -j "$CHAIN"

echo "Firewall enabled: only SSH (22) allowed on $PUBLIC_IF."
echo "Tailscale, k3s, and Docker traffic unaffected (different interfaces)."
