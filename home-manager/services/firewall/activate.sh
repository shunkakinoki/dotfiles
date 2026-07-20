#!/usr/bin/env bash
# Converge Kyber WAN firewall on every activation (IPv4 + IPv6).
# Public SSH is denied on the WAN NIC; access is via Tailscale (and Latitude SG).
set -euo pipefail

CHAIN="kyber-firewall"

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

ip6t() {
  run_root @ip6tables@ "$@"
}

detect_public_if() {
  local ifc=""
  if [ -n "${KYBER_PUBLIC_IF:-}" ]; then
    printf '%s\n' "$KYBER_PUBLIC_IF"
    return 0
  fi

  ifc="$(@ip@ -4 route show default 2>/dev/null | awk '/default/ {
    for (i = 1; i <= NF; i++) {
      if ($i == "dev") {
        print $(i + 1)
        exit
      }
    }
  }')"

  if [ -z "$ifc" ]; then
    echo "Could not detect public interface (no default IPv4 route). Set KYBER_PUBLIC_IF." >&2
    exit 1
  fi

  if [ ! -d "/sys/class/net/$ifc" ]; then
    echo "Detected public interface '$ifc' does not exist. Set KYBER_PUBLIC_IF." >&2
    exit 1
  fi

  printf '%s\n' "$ifc"
}

# Remove every INPUT jump into CHAIN, then attach for the current WAN NIC.
resync_input_jump() {
  local ipt_cmd="$1"
  local public_if="$2"
  local rule

  while IFS= read -r rule; do
    # shellcheck disable=SC2086
    $ipt_cmd -D ${rule#-A }
  done < <($ipt_cmd -S INPUT 2>/dev/null | awk -v chain="$CHAIN" '
    $1 == "-A" && $0 ~ ("-j " chain "$") { print }
  ' || true)

  $ipt_cmd -I INPUT 1 -i "$public_if" -j "$CHAIN"
}

ensure_chain() {
  local ipt_cmd="$1"

  if $ipt_cmd -L "$CHAIN" -n >/dev/null 2>&1; then
    $ipt_cmd -F "$CHAIN"
  else
    $ipt_cmd -N "$CHAIN"
  fi

  # Established/related only. No public SSH: Tailscale + Latitude SG own remote access.
  $ipt_cmd -A "$CHAIN" -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
  $ipt_cmd -A "$CHAIN" -j DROP
}

PUBLIC_IF="$(detect_public_if)"

echo "Converging firewall on $PUBLIC_IF (IPv4 + IPv6)..."

ensure_chain ipt
resync_input_jump ipt "$PUBLIC_IF"

ensure_chain ip6t
resync_input_jump ip6t "$PUBLIC_IF"

echo "Firewall enabled: WAN $PUBLIC_IF drops all new ingress (SSH via Tailscale only)."
echo "Tailscale, k3s, and container traffic on other interfaces are unaffected."
