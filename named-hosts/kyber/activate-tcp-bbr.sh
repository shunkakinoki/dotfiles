#!/usr/bin/env bash
# Use BBR on Kyber's sender side (requires sudo/doas). Its long tailnet paths
# lose a few percent of segments, which pins cubic's window to a handful of
# packets; BBR paces from measured bandwidth instead of backing off on loss.
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
  echo "TCP BBR requires root privileges, but sudo/doas is not available." >&2
  exit 1
fi

run_root_cmd() {
  if [ -n "$SUDO_CMD" ]; then
    "$SUDO_CMD" "$@"
  else
    "$@"
  fi
}

if [ "$(cat /proc/sys/net/core/default_qdisc)" != "fq" ]; then
  run_root_cmd sysctl -w net.core.default_qdisc=fq
fi
if [ "$(cat /proc/sys/net/ipv4/tcp_congestion_control)" != "bbr" ]; then
  echo "Enabling TCP BBR congestion control..."
  run_root_cmd modprobe tcp_bbr
  run_root_cmd sysctl -w net.ipv4.tcp_congestion_control=bbr
fi

write_if_changed() {
  local path="$1" content="$2"
  if [ "$(cat "$path" 2>/dev/null)" != "$content" ]; then
    printf '%s\n' "$content" | run_root_cmd tee "$path" >/dev/null
  fi
}
write_if_changed /etc/modules-load.d/tcp_bbr.conf 'tcp_bbr'
write_if_changed /etc/sysctl.d/99-tcp-bbr.conf "$(printf '%s\n' 'net.core.default_qdisc=fq' 'net.ipv4.tcp_congestion_control=bbr')"
