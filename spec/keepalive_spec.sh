#!/usr/bin/env bash
# shellcheck disable=SC2329

Describe 'captive portal detection'
SCRIPT="$PWD/home-manager/services/neverssl-keepalive/keepalive.sh"

setup() {
  mock_bin_setup curl networksetup ipconfig open date
  export MOCK_LOG="${MOCK_LOG:?}"
  export XDG_STATE_HOME="$MOCK_BIN/state"
  export PROBE_SCENARIO=online MOCK_NOW=1700000000 MOCK_ADDRESS=192.0.2.2
  export MOCK_OPEN_EXIT=0 MOCK_OS=darwin

  cat >"$MOCK_BIN/networksetup" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "networksetup $*" >>"$MOCK_LOG"
printf 'Hardware Port: Ethernet\nDevice: en0\n\nHardware Port: Wi-Fi\nDevice: en7\n'
EOF
  cat >"$MOCK_BIN/ipconfig" <<'EOF'
#!/usr/bin/env bash
case $1 in
  getifaddr) printf '%s\n' "$MOCK_ADDRESS" ;;
  getoption) printf '192.0.2.1\n' ;;
esac
EOF
  cat >"$MOCK_BIN/open" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "open $*" >>"$MOCK_LOG"
exit "$MOCK_OPEN_EXIT"
EOF
  cat >"$MOCK_BIN/date" <<'EOF'
#!/usr/bin/env bash
if [[ ${1:-} == +%s ]]; then
  printf '%s\n' "$MOCK_NOW"
else
  printf 'test-time\n'
fi
EOF
  cat >"$MOCK_BIN/curl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "curl $*" >>"$MOCK_LOG"
body_file=''
url=${!#}
while (( $# )); do
  if [[ $1 == --output ]]; then
    body_file=$2
    shift
  fi
  shift
done
status=200
case $url in
  *captive.apple.com*) body='<HTML><HEAD><TITLE>Success</TITLE></HEAD><BODY>Success</BODY></HTML>' ;;
  *gstatic.com*) status=204; body='' ;;
  *msftconnecttest.com*) body='Microsoft Connect Test' ;;
  *) exit 99 ;;
esac
case $PROBE_SCENARIO in
  timeout) exit 28 ;;
  dns) exit 6 ;;
  server-error) status=503; body='Temporarily unavailable' ;;
  redirect) status=302; body='' ;;
  login) status=200; body='<html>Sign in</html>' ;;
  network-auth) status=511; body='' ;;
  partial-login)
    if [[ $url == *captive.apple.com* ]]; then status=302; body=''; fi ;;
  partial-outage)
    if [[ $url == *captive.apple.com* ]]; then exit 28; fi ;;
  truncated) printf '<html>Sign in' >"$body_file"; exit 18 ;;
  invalid-204) status=204; body='Unexpected content' ;;
esac
printf '%s' "$body" >"$body_file"
printf '%s' "$status"
EOF
}

cleanup() {
  unset XDG_STATE_HOME PROBE_SCENARIO MOCK_NOW MOCK_ADDRESS MOCK_OPEN_EXIT MOCK_OS
  mock_bin_cleanup
}

run_detector() {
  OSTYPE="$MOCK_OS" bash "$SCRIPT" "$@"
}

run_with_calls() {
  run_detector "$@"
  cat "$MOCK_LOG"
}

Before 'setup'
After 'cleanup'

It 'validates successful responses without opening a browser'
When call run_with_calls
The status should be success
The output should include 'ONLINE'
The output should not include 'open http'
The output should not include 'neverssl.com'
End

It 'discovers and binds to the Wi-Fi interface without querying the SSID'
When call run_with_calls
The output should include '--interface en7'
The output should not include '-getairportnetwork'
The output should not include '-setairportpower'
End

It 'ignores curl configuration and proxies without following redirects'
When call run_with_calls
The output should include 'curl --disable --noproxy *'
The output should include '--connect-timeout 2 --max-time 4 --max-filesize 65536'
The output should not include '--location'
End

Describe 'unavailable probes'
Parameters
timeout
dns
server-error
truncated
invalid-204
End
It 'reports unavailable probes without opening a browser or restarting Wi-Fi'
export PROBE_SCENARIO="$1"
When call run_with_calls
The status should be success
The output should include 'OFFLINE'
The output should not include 'CAPTIVE'
The output should not include 'open http'
The output should not include '-setairportpower'
End
End

Describe 'portal responses'
Parameters
redirect
login
network-auth
partial-login
End
It 'opens a known HTTP probe when login is required, including whitelisted probes'
export PROBE_SCENARIO="$1"
When call run_with_calls
The status should be success
The output should include 'CAPTIVE'
The output should include 'open http://'
The output should not include '-setairportpower'
End
End

It 'continues detecting online access when one provider is unavailable'
export PROBE_SCENARIO=partial-outage
When call run_with_calls
The output should include 'ONLINE'
The output should not include 'open http'
End

It 'does not probe or open anything without a Wi-Fi address'
export MOCK_ADDRESS=''
When call run_with_calls
The status should be success
The output should include 'OFFLINE (no Wi-Fi IPv4 address)'
The output should not include 'curl '
The output should not include 'open http'
End

It 'does not open a browser or write cooldown state in check mode'
export PROBE_SCENARIO=login
When call run_with_calls --check
The output should include 'CAPTIVE'
The output should not include 'open http'
The path "$XDG_STATE_HOME" should not be exist
End

run_cooldown() {
  PROBE_SCENARIO=login run_detector
  PROBE_SCENARIO=online run_detector
  PROBE_SCENARIO=timeout run_detector
  PROBE_SCENARIO=login MOCK_NOW=1700000599 run_detector
  cat "$MOCK_LOG"
}
count_openings() {
  awk '/^open / { count++ } END { print count + 0 }' "$MOCK_LOG"
}
cooldown_openings() {
  run_cooldown >/dev/null
  count_openings
}
It 'persists exactly one browser opening across repeated service invocations'
When call cooldown_openings
The output should eq '1'
End

corrupt_state_openings() {
  PROBE_SCENARIO=login run_detector >/dev/null
  printf 'invalid\n' >"$XDG_STATE_HOME"/neverssl-keepalive/*.last-opened
  PROBE_SCENARIO=login run_detector >/dev/null
  count_openings
}
It 'recovers from a corrupt cooldown file'
When call corrupt_state_openings
The output should eq '2'
End

clock_reset_openings() {
  PROBE_SCENARIO=login run_detector >/dev/null
  PROBE_SCENARIO=login MOCK_NOW=1699999999 run_detector >/dev/null
  count_openings
}
It 'recovers from a backwards clock adjustment'
When call clock_reset_openings
The output should eq '2'
End

expired_openings() {
  PROBE_SCENARIO=login run_detector >/dev/null
  PROBE_SCENARIO=login MOCK_NOW=1700000600 run_detector >/dev/null
  count_openings
}
It 'allows another login reminder after ten minutes'
When call expired_openings
The output should eq '2'
End

changed_network_openings() {
  PROBE_SCENARIO=login run_detector >/dev/null
  PROBE_SCENARIO=login MOCK_ADDRESS=192.0.2.3 run_detector >/dev/null
  count_openings
}
It 'allows login on a different network during the cooldown'
When call changed_network_openings
The output should eq '2'
End

failed_openings() {
  PROBE_SCENARIO=login MOCK_OPEN_EXIT=1 run_detector >/dev/null
  PROBE_SCENARIO=login run_detector >/dev/null
  count_openings
}
It 'does not suppress a later attempt after the browser could not open'
When call failed_openings
The output should eq '2'
The stderr should include 'Could not open captive portal'
End

It 'reports captive status on Linux without using macOS commands'
export PROBE_SCENARIO=login MOCK_OS=linux-gnu
When call run_with_calls
The status should be success
The output should include 'CAPTIVE'
The output should not include 'networksetup '
The output should not include '--interface'
The output should not include 'open http'
End

It 'rejects unknown options before probing'
When call run_detector --unknown
The status should eq 2
The stderr should include 'Usage:'
The output should eq ''
End
End
