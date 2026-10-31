#!/usr/bin/env bash
# shellcheck disable=SC2016,SC2329

Describe 'nix-darwin/services/iron-proxy/guard.sh'
SCRIPT="$PWD/nix-darwin/services/iron-proxy/guard.sh"

setup_guard() {
  TEST_DIR=$(mktemp -d)
  BIN="$TEST_DIR/bin"
  mkdir -p "$BIN"
  PF_LOG="$TEST_DIR/pfctl.log"
  : >"$PF_LOG"

  cat >"$BIN/pfctl" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$PF_LOG"
if [ "$*" = "-a ironproxy -s rules" ]; then
  [ -n "${PF_LOADED:-}" ] && echo "pass out log quick"
fi
if [ "$*" = "-q -a ironproxy-captive -f -" ]; then
  cat >>"$PF_LOG"
fi
case "$*" in "-q -a ironproxy-captive -f -" | "-q -a ironproxy-captive -F rules") exit "${PF_STATUS:-0}" ;; esac
exit 0
EOF
  cat >"$BIN/curl" <<'EOF'
#!/usr/bin/env bash
case "$PROBE" in
success) echo '<HTML><HEAD><TITLE>Success</TITLE></HEAD><BODY>Success</BODY></HTML>' ;;
captive) echo '<html>hotel login</html>' ;;
*) exit 7 ;;
esac
EOF
  cat >"$BIN/route" <<'EOF'
#!/usr/bin/env bash
printf '   route to: default\n    gateway: %s\n' "$GATEWAY"
EOF
  cat >"$BIN/iron-proxy" <<'EOF'
#!/usr/bin/env bash
outdir=$3
echo cert >"$outdir/ca.crt"
echo key >"$outdir/ca.key"
EOF
  cat >"$BIN/networksetup" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$NS_LOG"
case "$1" in
-getsecurewebproxy) printf 'Enabled: %s\nServer: %s\nPort: %s\n' "${NS_ENABLED:-No}" "${NS_SERVER:-127.0.0.1}" "${NS_PORT:-0}" ;;
-getwebproxy) printf 'Enabled: %s\nServer: %s\nPort: %s\n' "${NS_WEB_ENABLED:-${NS_ENABLED:-No}}" "${NS_SERVER:-127.0.0.1}" "${NS_WEB_PORT:-${NS_PORT:-0}}" ;;
esac
EOF
  printf '#!/usr/bin/env bash\nexit 0\n' >"$BIN/chown"
  printf '#!/usr/bin/env bash\nexit "${NC_STATUS:-1}"\n' >"$BIN/nc"
  printf '#!/usr/bin/env bash\nexit "${TRUST_STATUS:-1}"\n' >"$BIN/security"
  echo roots >"$TEST_DIR/roots.crt"
  chmod +x "$BIN"/*

  sed \
    -e "s|@ironProxyBin@|$BIN/iron-proxy|g" \
    -e "s|@stateDir@|$TEST_DIR/state|g" \
    -e "s|@guardStateDir@|$TEST_DIR/guard|g" \
    -e 's|@proxyUser@|iron-proxy|g' \
    -e 's|@agentUid@|501|g' \
    -e 's|@pfConf@|/etc/pf.ironproxy.conf|g' \
    -e 's|@captiveWindowSeconds@|600|g' \
    -e "s|@systemProxy@|${SYSTEM_PROXY:-0}|g" \
    -e 's|@proxyPort@|8899|g' \
    -e 's|@networkServices@|Wi-Fi|g' \
    -e 's|@bypassDomains@|localhost|g' \
    -e "s|@caBundle@|$TEST_DIR/roots.crt|g" \
    "$SCRIPT" >"$TEST_DIR/guard.sh"
}

cleanup_guard() {
  rm -rf "$TEST_DIR"
}

run_guard() {
  env PF_LOG="$PF_LOG" PFCTL_BIN="$BIN/pfctl" CURL_BIN="$BIN/curl" ROUTE_BIN="$BIN/route" \
    CHOWN_BIN="$BIN/chown" NC_BIN="$BIN/nc" SECURITY_BIN="$BIN/security" NETWORKSETUP_BIN="$BIN/networksetup" NS_LOG="$TEST_DIR/ns.log" PF_STATUS="${PF_STATUS:-0}" PF_LOADED=1 GATEWAY="${GATEWAY:-192.168.1.1}" \
    PROBE="$1" GUARD_NOW="$2" bash "$TEST_DIR/guard.sh" >/dev/null
}

Describe 'script properties'
Before 'setup_guard'
After 'cleanup_guard'
It 'passes bash syntax check after replacing placeholders'
When run bash -n "$TEST_DIR/guard.sh"
The status should be success
End
End

Describe 'captive portal handling'
Before 'setup_guard'
After 'cleanup_guard'

It 'generates the CA and reloads pf when the anchor is missing'
When run bash -c "env PF_LOG='$PF_LOG' PFCTL_BIN='$BIN/pfctl' CURL_BIN='$BIN/curl' ROUTE_BIN='$BIN/route' CHOWN_BIN='$BIN/chown' NC_BIN='$BIN/nc' SECURITY_BIN='$BIN/security' GATEWAY=10.0.0.1 PROBE=success GUARD_NOW=1000 bash '$TEST_DIR/guard.sh' >/dev/null; cat '$PF_LOG'; test -s '$TEST_DIR/state/ca.key' && echo ca-ok"
The output should include '-q -f /etc/pf.ironproxy.conf'
The output should include 'ca-ok'
End

It 'opens a web-only window on a captive network'
When run bash -c "$(declare -f run_guard); BIN='$BIN' PF_LOG='$PF_LOG' TEST_DIR='$TEST_DIR'; run_guard captive 1000; cat '$PF_LOG' '$TEST_DIR/guard/window'"
The output should include 'pass out quick proto tcp to any port { 80, 443 } user 501'
The output should include 'captive 1600 192.168.1.1'
End

It 'closes the window once the portal login succeeds'
When run bash -c "$(declare -f run_guard); BIN='$BIN' PF_LOG='$PF_LOG' TEST_DIR='$TEST_DIR'; run_guard captive 1000; run_guard success 1100; cat '$PF_LOG'; test -e '$TEST_DIR/guard/window' || echo window-gone"
The output should include '-q -a ironproxy-captive -F rules'
The output should include 'window-gone'
End

It 'closes an expired window and does not reopen it on the same network'
When run bash -c "$(declare -f run_guard); BIN='$BIN' PF_LOG='$PF_LOG' TEST_DIR='$TEST_DIR'; run_guard captive 1000; run_guard captive 1700; : >'$PF_LOG'; run_guard captive 1800; cat '$PF_LOG'; test -e '$TEST_DIR/guard/applied' || echo strict"
The output should not include 'port { 80, 443 }'
The output should include 'strict'
End

It 'opens a fresh window when the gateway changes'
When run bash -c "$(declare -f run_guard); BIN='$BIN' PF_LOG='$PF_LOG' TEST_DIR='$TEST_DIR'; run_guard captive 1000; run_guard captive 1700; GATEWAY=172.16.0.1 run_guard captive 1800; cat '$TEST_DIR/guard/window' '$TEST_DIR/guard/applied'"
The output should include 'captive 2400 172.16.0.1'
The line 2 of output should equal 'captive'
End

It 'keeps a manual window open regardless of the probe until it expires'
When run bash -c "$(declare -f run_guard); BIN='$BIN' PF_LOG='$PF_LOG' TEST_DIR='$TEST_DIR'; mkdir -p '$TEST_DIR/guard'; echo 'manual 2000 -' >'$TEST_DIR/guard/window'; run_guard success 1500; cat '$TEST_DIR/guard/applied'; run_guard success 2100; test -e '$TEST_DIR/guard/applied' || echo closed"
The line 1 of output should equal 'manual'
The line 2 of output should equal 'closed'
End

It 'keeps the applied marker when pfctl fails so the next run retries'
When run bash -c "$(declare -f run_guard); BIN='$BIN' PF_LOG='$PF_LOG' TEST_DIR='$TEST_DIR'; PF_STATUS=1 run_guard captive 1000; test -e '$TEST_DIR/guard/applied' || echo not-applied; run_guard captive 1100; PF_STATUS=1 run_guard success 1200; cat '$TEST_DIR/guard/applied'"
The line 1 of output should equal 'not-applied'
The line 2 of output should equal 'captive'
End
End

Describe 'proxy env readiness'
Before 'setup_guard'
After 'cleanup_guard'

It 'builds a CA bundle with the public roots and the local CA'
When run bash -c "$(declare -f run_guard); BIN='$BIN' PF_LOG='$PF_LOG' TEST_DIR='$TEST_DIR'; run_guard success 1000; cat '$TEST_DIR/state/ca-bundle.crt'"
The line 1 of output should equal 'roots'
The line 2 of output should equal 'cert'
End

It 'marks env ready only when the proxy listens and the CA is trusted'
When run bash -c "$(declare -f run_guard); BIN='$BIN' PF_LOG='$PF_LOG' TEST_DIR='$TEST_DIR'; NC_STATUS=0 run_guard success 1000; test -e '$TEST_DIR/state/env-ready' || echo untrusted; NC_STATUS=0 TRUST_STATUS=0 run_guard success 1100; test -e '$TEST_DIR/state/env-ready' && echo ready; TRUST_STATUS=0 run_guard success 1200; test -e '$TEST_DIR/state/env-ready' || echo down"
The line 1 of output should equal 'untrusted'
The line 2 of output should equal 'ready'
The line 3 of output should equal 'down'
End
End

Describe 'system proxy'
setup_system_proxy() {
  SYSTEM_PROXY=1 setup_guard
}
Before 'setup_system_proxy'
After 'cleanup_guard'

It 'sets the system proxy once the env is ready'
When run bash -c "$(declare -f run_guard); BIN='$BIN' PF_LOG='$PF_LOG' TEST_DIR='$TEST_DIR'; NC_STATUS=0 TRUST_STATUS=0 run_guard success 1000; cat '$TEST_DIR/ns.log'"
The output should include '-setwebproxy Wi-Fi 127.0.0.1 8899'
The output should include '-setsecurewebproxy Wi-Fi 127.0.0.1 8899'
The output should include '-setproxybypassdomains Wi-Fi localhost'
End

It 'leaves an already-set system proxy alone'
When run bash -c "$(declare -f run_guard); BIN='$BIN' PF_LOG='$PF_LOG' TEST_DIR='$TEST_DIR'; NS_ENABLED=Yes NS_PORT=8899 NC_STATUS=0 TRUST_STATUS=0 run_guard success 1000; cat '$TEST_DIR/ns.log'"
The output should not include '-set'
End

It 'reconciles HTTP separately from HTTPS'
When run bash -c "$(declare -f run_guard); BIN='$BIN' PF_LOG='$PF_LOG' TEST_DIR='$TEST_DIR'; NS_ENABLED=Yes NS_PORT=8899 NS_WEB_ENABLED=No NC_STATUS=0 TRUST_STATUS=0 run_guard success 1000; cat '$TEST_DIR/ns.log'"
The output should include '-setwebproxy Wi-Fi 127.0.0.1 8899'
The output should not include '-setsecurewebproxy'
End

It 'clears its own system proxy when the env is not ready'
When run bash -c "$(declare -f run_guard); BIN='$BIN' PF_LOG='$PF_LOG' TEST_DIR='$TEST_DIR'; NS_ENABLED=Yes NS_PORT=8899 run_guard success 1000; cat '$TEST_DIR/ns.log'"
The output should include '-setsecurewebproxystate Wi-Fi off'
The output should include '-setwebproxystate Wi-Fi off'
End

It 'keeps a foreign system proxy when the env is not ready'
When run bash -c "$(declare -f run_guard); BIN='$BIN' PF_LOG='$PF_LOG' TEST_DIR='$TEST_DIR'; NS_ENABLED=Yes NS_PORT=3128 run_guard success 1000; cat '$TEST_DIR/ns.log'"
The output should include '-getsecurewebproxy Wi-Fi'
The output should not include '-set'
End

It 'keeps a foreign proxy on the same port when the env is not ready'
When run bash -c "$(declare -f run_guard); BIN='$BIN' PF_LOG='$PF_LOG' TEST_DIR='$TEST_DIR'; NS_ENABLED=Yes NS_PORT=8899 NS_SERVER=10.0.0.5 run_guard success 1000; cat '$TEST_DIR/ns.log'"
The output should include '-getsecurewebproxy Wi-Fi'
The output should not include '-set'
End

It 'does not overwrite a foreign system proxy once the env is ready'
When run bash -c "$(declare -f run_guard); BIN='$BIN' PF_LOG='$PF_LOG' TEST_DIR='$TEST_DIR'; NS_ENABLED=Yes NS_PORT=3128 NC_STATUS=0 TRUST_STATUS=0 run_guard success 1000; cat '$TEST_DIR/ns.log'"
The output should include '-getsecurewebproxy Wi-Fi'
The output should not include '-set'
End

It 'keeps the shared bypass list while one protocol is foreign'
When run bash -c "$(declare -f run_guard); BIN='$BIN' PF_LOG='$PF_LOG' TEST_DIR='$TEST_DIR'; NS_ENABLED=Yes NS_PORT=3128 NS_WEB_ENABLED=No NC_STATUS=0 TRUST_STATUS=0 run_guard success 1000; cat '$TEST_DIR/ns.log'"
The output should include '-setwebproxy Wi-Fi 127.0.0.1 8899'
The output should not include '-setproxybypassdomains'
End

End
End
