#!/usr/bin/env bash
# Replaces the running CLIProxyAPI container with a new image while the port
# keeps accepting connections. The server binds the host network directly, so
# two instances cannot share the port: a standby on another port takes new
# connections through a NAT redirect while the systemd unit restarts.
set -euo pipefail

image="${1:?usage: swap.sh <image>}"
port="${CLIPROXY_PORT:-8317}"
standby_port="${CLIPROXY_STANDBY_PORT:-8318}"
drain_seconds="${CLIPROXY_SWAP_DRAIN_SECONDS:-120}"
config_dir="${HOME}/.cli-proxy-api"
standby_config="${config_dir}/config.standby.yaml"
standby="cliproxyapi-standby"
# Ingress reaches the server from the pod network, which enters through
# PREROUTING. Local clients (OUTPUT) are left alone so the health checks below
# keep reaching the real unit.
redirect=(PREROUTING -p tcp --dport "$port" -m comment --comment "$standby"
  -j REDIRECT --to-ports "$standby_port")

serving() {
  curl -s -o /dev/null --max-time 2 "http://127.0.0.1:$1/"
}

wait_serving() {
  for _ in $(seq 1 60); do
    serving "$1" && return 0
    sleep 1
  done
  return 1
}

restart_unit() {
  systemctl --user restart cliproxyapi.service
  if ! wait_serving "$port"; then
    echo "❌ cliproxyapi did not come back on :$port" >&2
    return 1
  fi
  echo "✅ cliproxyapi is serving on :$port"
}

if ! sudo -n iptables -t nat -L PREROUTING -n >/dev/null 2>&1; then
  echo "⚠️  No non-interactive iptables access; restarting cliproxyapi in place" >&2
  restart_unit
  exit 0
fi

cleanup() {
  while sudo -n iptables -t nat -D "${redirect[@]}" 2>/dev/null; do :; done
  docker rm -f "$standby" >/dev/null 2>&1 || true
  rm -f "$standby_config"
}
trap cleanup EXIT
cleanup

sed "s/^port: ${port}\$/port: ${standby_port}/" "${config_dir}/config.yaml" >"$standby_config"
if ! grep -qx "port: ${standby_port}" "$standby_config"; then
  echo "❌ ${config_dir}/config.yaml does not declare port: ${port}" >&2
  exit 1
fi

docker run -d --rm \
  --name "$standby" \
  --network host \
  --ulimit nofile=65536:65536 \
  -v "$standby_config:/CLIProxyAPI/config.yaml:ro" \
  -v "$config_dir:/root/.cli-proxy-api" \
  -e MANAGEMENT_PASSWORD="${CLIPROXY_MANAGEMENT_PASSWORD:-}" \
  "$image" >/dev/null
if ! wait_serving "$standby_port"; then
  echo "❌ standby did not start on :$standby_port" >&2
  exit 1
fi

sudo -n iptables -t nat -I "${redirect[@]}"
echo "🔀 New connections to :$port go to the standby on :$standby_port"
restart_unit
sudo -n iptables -t nat -D "${redirect[@]}"

# Connections the redirect already handed to the standby stay NATed to it, so
# let in-flight streams finish before stopping it.
for _ in $(seq 1 "$drain_seconds"); do
  [ -z "$(ss -Htn state established "( sport = :$standby_port )")" ] && break
  sleep 1
done
