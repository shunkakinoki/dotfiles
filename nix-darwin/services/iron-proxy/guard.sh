#!/usr/bin/env bash
set -u

iron_proxy_bin="@ironProxyBin@"
state_dir="@stateDir@"
guard_state_dir="@guardStateDir@"
proxy_user="@proxyUser@"
agent_uid="@agentUid@"
pf_conf="@pfConf@"
captive_window_seconds=@captiveWindowSeconds@
system_proxy="@systemProxy@"
proxy_port="@proxyPort@"
network_services="@networkServices@"
bypass_domains="@bypassDomains@"

pfctl_bin="${PFCTL_BIN:-/sbin/pfctl}"
curl_bin="${CURL_BIN:-/usr/bin/curl}"
route_bin="${ROUTE_BIN:-/sbin/route}"
networksetup_bin="${NETWORKSETUP_BIN:-/usr/sbin/networksetup}"
chown_bin="${CHOWN_BIN:-/usr/sbin/chown}"
now="${GUARD_NOW:-$(date +%s)}"
window_file="$guard_state_dir/window"

log() {
  printf '%s iron-proxy-guard: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*"
}

ensure_ca() {
  mkdir -p "$state_dir"
  if [ ! -s "$state_dir/ca.key" ]; then
    "$iron_proxy_bin" generate-ca -outdir "$state_dir" -name "iron-proxy local CA" -expiry-hours 26280 >/dev/null
    log "generated CA at $state_dir/ca.crt"
  fi
  "$chown_bin" -R "$proxy_user:$proxy_user" "$state_dir"
  chmod 755 "$state_dir"
  chmod 600 "$state_dir/ca.key"
  chmod 644 "$state_dir/ca.crt"
}

# macOS reloads /etc/pf.conf on some network and sharing changes, which drops
# our anchors, so the guard re-asserts them on every run.
ensure_pf() {
  if [ -z "$("$pfctl_bin" -a ironproxy -s rules 2>/dev/null)" ]; then
    "$pfctl_bin" -q -f "$pf_conf" && log "loaded $pf_conf"
    rm -f "$guard_state_dir/applied"
  fi
  "$pfctl_bin" -q -e >/dev/null 2>&1 || true
}

ensure_system_proxy() {
  [ "$system_proxy" = "1" ] || return 0
  local service
  local IFS=:
  for service in $network_services; do
    "$networksetup_bin" -getwebproxy "$service" >/dev/null 2>&1 || continue
    if ! "$networksetup_bin" -getsecurewebproxy "$service" | grep -q "^Port: $proxy_port$"; then
      "$networksetup_bin" -setwebproxy "$service" 127.0.0.1 "$proxy_port"
      "$networksetup_bin" -setsecurewebproxy "$service" 127.0.0.1 "$proxy_port"
      IFS=' ' read -r -a domains <<<"$bypass_domains"
      "$networksetup_bin" -setproxybypassdomains "$service" "${domains[@]}"
      log "set system proxy on $service"
    fi
  done
}

window_rule() {
  case "$1" in
  captive) printf 'pass out quick proto tcp to any port { 80, 443 } user %s\n' "$agent_uid" ;;
  manual) printf 'pass out quick proto { tcp udp } user %s\n' "$agent_uid" ;;
  esac
}

apply_window() {
  local kind="$1"
  if [ "$(cat "$guard_state_dir/applied" 2>/dev/null)" != "$kind" ]; then
    window_rule "$kind" | "$pfctl_bin" -q -a ironproxy-captive -f -
    printf '%s\n' "$kind" >"$guard_state_dir/applied"
    log "opened $kind window"
  fi
}

close_window() {
  if [ -e "$guard_state_dir/applied" ]; then
    "$pfctl_bin" -q -a ironproxy-captive -F rules
    rm -f "$guard_state_dir/applied"
    log "closed bypass window ($1)"
  fi
}

# Prints "success", "captive" or "offline". Runs as root, so pf's agent rules
# do not apply and the probe sees the raw network.
probe_network() {
  local body
  if ! body="$("$curl_bin" -s -m 5 --noproxy '*' http://captive.apple.com/hotspot-detect.html)"; then
    echo offline
  elif printf '%s' "$body" | grep -q '<TITLE>Success</TITLE>'; then
    echo success
  else
    echo captive
  fi
}

current_network() {
  "$route_bin" -n get default 2>/dev/null | awk '/gateway:/ { print $2; exit }'
}

reconcile_window() {
  local kind="" expires=0 network="" state gateway
  if [ -s "$window_file" ]; then
    read -r kind expires network <"$window_file"
  fi

  if [ "$kind" = "manual" ]; then
    if [ "$now" -lt "$expires" ]; then
      apply_window manual
      return
    fi
    rm -f "$window_file"
    close_window "manual expired"
    kind=""
  fi

  state="$(probe_network)"
  gateway="$(current_network)"
  case "$state" in
  success)
    rm -f "$window_file"
    close_window "network is online"
    ;;
  captive)
    # One window per network: an expired window is not reopened until the
    # gateway changes or the portal login succeeds.
    if [ "$kind" != "captive" ] || [ "$network" != "$gateway" ]; then
      expires=$((now + captive_window_seconds))
      printf 'captive %s %s\n' "$expires" "$gateway" >"$window_file"
    fi
    if [ "$now" -lt "$expires" ]; then
      apply_window captive
    else
      close_window "captive window expired"
    fi
    ;;
  offline)
    if [ "$kind" = "captive" ] && [ "$now" -ge "$expires" ]; then
      close_window "captive window expired"
    fi
    ;;
  esac
}

main() {
  mkdir -p "$guard_state_dir"
  chmod 700 "$guard_state_dir"
  ensure_ca
  ensure_pf
  ensure_system_proxy
  reconcile_window
}

main "$@"
