#!/usr/bin/env bash
set -u

iron_proxy_bin="@ironProxyBin@"
state_dir="@stateDir@"
guard_state_dir="@guardStateDir@"
proxy_user="@proxyUser@"
agent_uid="@agentUid@"
pf_conf="@pfConf@"
pf_anchor="@pfAnchor@"
captive_window_seconds=@captiveWindowSeconds@
system_proxy="@systemProxy@"
proxy_port="@proxyPort@"
network_services="@networkServices@"
bypass_domains="@bypassDomains@"
ca_bundle="@caBundle@"

pfctl_bin="${PFCTL_BIN:-/sbin/pfctl}"
curl_bin="${CURL_BIN:-/usr/bin/curl}"
route_bin="${ROUTE_BIN:-/sbin/route}"
networksetup_bin="${NETWORKSETUP_BIN:-/usr/sbin/networksetup}"
chown_bin="${CHOWN_BIN:-/usr/sbin/chown}"
nc_bin="${NC_BIN:-/usr/bin/nc}"
security_bin="${SECURITY_BIN:-/usr/bin/security}"
now="${GUARD_NOW:-$(date +%s)}"
window_file="$guard_state_dir/window"

log() {
  printf '%s iron-proxy-guard: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*"
}

# Root owns the directory and files so the proxy user, which only needs to
# read the key, cannot plant symlinks that root later writes through.
ensure_ca() {
  local path
  [ -L "$state_dir" ] && rm -f "$state_dir"
  mkdir -p "$state_dir"
  # Taken first: older builds left the directory proxy-owned, so the proxy
  # could otherwise race a symlink in between the cleanup and the chowns.
  "$chown_bin" root:wheel "$state_dir"
  chmod 755 "$state_dir"
  for path in ca.key ca.crt ca-bundle.crt ca-bundle.crt.tmp env-ready; do
    [ -L "$state_dir/$path" ] && rm -f "$state_dir/$path"
  done
  if [ ! -s "$state_dir/ca.key" ]; then
    (umask 077 && "$iron_proxy_bin" generate-ca -outdir "$state_dir" -name "iron-proxy local CA" -expiry-hours 26280 >/dev/null)
    log "generated CA at $state_dir/ca.crt"
  fi
  "$chown_bin" root:wheel "$state_dir/ca.crt"
  "$chown_bin" "root:$proxy_user" "$state_dir/ca.key"
  chmod 640 "$state_dir/ca.key"
  chmod 644 "$state_dir/ca.crt"
}

# Non-Keychain TLS clients (Nix curl, Python, Rust) read a PEM bundle, so the
# local CA is appended to the public roots.
ensure_bundle() {
  cat "$ca_bundle" "$state_dir/ca.crt" >"$state_dir/ca-bundle.crt.tmp"
  chmod 644 "$state_dir/ca-bundle.crt.tmp"
  mv -f "$state_dir/ca-bundle.crt.tmp" "$state_dir/ca-bundle.crt"
}

# env-ready tells the per-user env agent it is safe to point clients at the
# proxy: the tunnel answers and the CA is trusted in the System keychain.
ensure_env_ready() {
  if "$nc_bin" -z -G 2 127.0.0.1 "$proxy_port" >/dev/null 2>&1 &&
    "$security_bin" verify-cert -q -c "$state_dir/ca.crt" >/dev/null 2>&1; then
    if [ ! -e "$state_dir/env-ready" ]; then
      touch "$state_dir/env-ready"
      log "proxy env enabled"
    fi
  elif [ -e "$state_dir/env-ready" ]; then
    rm -f "$state_dir/env-ready"
    log "proxy env disabled"
  fi
}

# macOS reloads /etc/pf.conf on some network and sharing changes, which drops
# our anchors, so the guard re-asserts them on every run. A rebuild that
# changes the rules (log to enforce) leaves the old ones loaded, so the
# checksum of the files last loaded is compared too. Such a reload can keep
# the anchor's rules while detaching it from the main ruleset, so both are
# checked.
ensure_pf() {
  local sum
  sum="$(cat "$pf_conf" "$pf_anchor" 2>/dev/null | cksum)"
  if ! "$pfctl_bin" -s rules 2>/dev/null | grep -q '^anchor "ironproxy"' ||
    [ -z "$("$pfctl_bin" -a ironproxy -s rules 2>/dev/null)" ] ||
    [ "$sum" != "$(cat "$guard_state_dir/pf-loaded" 2>/dev/null)" ]; then
    # A reload keeps the captive anchor's rules, so the applied marker is
    # dropped only once that anchor is flushed too; reconcile_window then
    # reapplies a window that is still valid.
    if "$pfctl_bin" -q -f "$pf_conf"; then
      printf '%s\n' "$sum" >"$guard_state_dir/pf-loaded"
      log "loaded $pf_conf"
      if "$pfctl_bin" -q -a ironproxy-captive -F rules; then
        rm -f "$guard_state_dir/applied"
      else
        log "failed to flush the bypass window after reload"
      fi
    else
      log "failed to load $pf_conf"
    fi
  fi
  "$pfctl_bin" -q -e >/dev/null 2>&1 || true
}

ours() {
  printf '%s\n' "$1" | grep -q '^Enabled: Yes$' &&
    printf '%s\n' "$1" | grep -q '^Server: 127\.0\.0\.1$' &&
    printf '%s\n' "$1" | grep -q "^Port: $proxy_port$"
}

# Gated on env-ready like the env agent: with the proxy down or its CA
# untrusted, a system proxy would cut every GUI app off, so it is cleared.
# An enabled proxy that is not ours is never touched, so nothing needs
# restoring when the env goes down. The bypass list is per service and shared
# by both protocols, so it is left alone while either one is foreign.
ensure_system_proxy() {
  [ "$system_proxy" = "1" ] || return 0
  local service kind current set_any foreign
  local IFS=:
  for service in $network_services; do
    set_any=""
    foreign=""
    for kind in web secureweb; do
      current="$("$networksetup_bin" "-get${kind}proxy" "$service" 2>/dev/null)" || continue 2
      if ours "$current"; then
        [ -e "$state_dir/env-ready" ] && continue
        if "$networksetup_bin" "-set${kind}proxystate" "$service" off; then
          log "cleared $kind proxy on $service"
        else
          log "failed to clear $kind proxy on $service"
        fi
      elif printf '%s\n' "$current" | grep -q '^Enabled: Yes$'; then
        foreign=1
      elif [ -e "$state_dir/env-ready" ]; then
        if "$networksetup_bin" "-set${kind}proxy" "$service" 127.0.0.1 "$proxy_port"; then
          set_any=1
          log "set $kind proxy on $service"
        else
          log "failed to set $kind proxy on $service"
        fi
      fi
    done
    if [ -n "$set_any" ] && [ -z "$foreign" ]; then
      IFS=' ' read -r -a domains <<<"$bypass_domains"
      "$networksetup_bin" -setproxybypassdomains "$service" "${domains[@]}"
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
    if window_rule "$kind" | "$pfctl_bin" -q -a ironproxy-captive -f -; then
      printf '%s\n' "$kind" >"$guard_state_dir/applied"
      log "opened $kind window"
    else
      log "failed to open $kind window"
    fi
  fi
}

# The applied marker stays until the flush succeeds so the next run retries.
close_window() {
  if [ -e "$guard_state_dir/applied" ]; then
    if "$pfctl_bin" -q -a ironproxy-captive -F rules; then
      rm -f "$guard_state_dir/applied"
      log "closed bypass window ($1)"
    else
      log "failed to close bypass window ($1)"
    fi
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
  ensure_bundle
  ensure_env_ready
  ensure_pf
  ensure_system_proxy
  reconcile_window
}

main "$@"
