guard_state_dir="@guardStateDir@"
agent_uid="@agentUid@"
pfctl_bin="${PFCTL_BIN:-/sbin/pfctl}"
max_minutes=60

usage() {
  echo "usage: sudo iron-proxy-bypass [minutes|off]  (default 10, max $max_minutes)" >&2
  exit 2
}

if [ "$(id -u)" -ne 0 ]; then
  echo "error: run with sudo" >&2
  exit 1
fi

arg="${1:-10}"
mkdir -p "$guard_state_dir"
chmod 700 "$guard_state_dir"

if [ "$arg" = "off" ]; then
  "$pfctl_bin" -q -a ironproxy-captive -F rules
  rm -f "$guard_state_dir/window" "$guard_state_dir/applied"
  echo "direct egress closed"
  exit 0
fi

case "$arg" in
'' | *[!0-9]*) usage ;;
esac
arg=$((10#$arg))
if [ "$arg" -lt 1 ] || [ "$arg" -gt "$max_minutes" ]; then
  usage
fi

expires=$(($(date +%s) + arg * 60))
printf 'pass out quick proto { tcp udp } user %s\n' "$agent_uid" | "$pfctl_bin" -q -a ironproxy-captive -f -
printf 'manual %s -\n' "$expires" >"$guard_state_dir/window"
printf 'manual\n' >"$guard_state_dir/applied"
echo "direct egress open for $arg minutes (until $(date -r "$expires" +%H:%M))"
