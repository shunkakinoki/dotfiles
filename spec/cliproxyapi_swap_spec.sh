#!/usr/bin/env bash
# shellcheck disable=SC2329,SC2016

Describe 'cliproxyapi swap.sh'
SCRIPT="$PWD/home-manager/services/cliproxyapi/scripts/swap.sh"

setup() {
  mock_bin_setup docker systemctl sleep
  TEMP_HOME=$(mktemp -d)
  mkdir -p "$TEMP_HOME/.cli-proxy-api"
  printf 'host: ""\n\nport: 8317\n' >"$TEMP_HOME/.cli-proxy-api/config.yaml"
  RULES="$MOCK_BIN/rules"
  echo 0 >"$RULES"
  export RULES
  # Tracks how many redirect rules are installed so `-D` fails once none are
  # left, like iptables does.
  cat >"$MOCK_BIN/sudo" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "sudo $*" >>"$MOCK_LOG"
[ "${NO_SUDO:-0}" = 1 ] && exit 1
rules="$(cat "$RULES")"
case " $* " in
  *" -I "*) echo $((rules + 1)) >"$RULES" ;;
  *" -C "*) [ "$rules" -gt 0 ] ;;
  *" -D "*)
    [ "${DELETE_FAILS:-0}" != 1 ] || exit 1
    [ "$rules" -gt 0 ] || exit 1
    echo $((rules - 1)) >"$RULES"
    ;;
esac
EOF
  cat >"$MOCK_BIN/curl" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "curl ${*: -1}" >>"$MOCK_LOG"
case "${*: -1}" in
  *:8318/) [ "${STANDBY_DOWN:-0}" != 1 ] ;;
  *:8317/) [ "${MAIN_DOWN:-0}" != 1 ] ;;
esac
EOF
  cat >"$MOCK_BIN/ss" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "ss $*" >>"$MOCK_LOG"
EOF
  chmod +x "$MOCK_BIN/sudo" "$MOCK_BIN/curl" "$MOCK_BIN/ss"
}

cleanup() {
  rm -rf "$TEMP_HOME"
  mock_bin_cleanup
}

Before 'setup'
After 'cleanup'

run_swap() {
  bash -c 'HOME="'"$TEMP_HOME"'" bash "'"$SCRIPT"'" example/image:new 2>&1; status=$?; cat "$MOCK_LOG"; echo "rules=$(cat "$RULES")"; exit "$status"'
}

It 'redirects new connections to a standby while the unit restarts'
When call run_swap
The status should be success
The output should match pattern '*docker run -d --rm --name cliproxyapi-standby --network host*config.standby.yaml:/CLIProxyAPI/config.yaml:ro*example/image:new*'
The output should match pattern '*curl http://127.0.0.1:8318/*-I PREROUTING -p tcp --dport 8317*REDIRECT --to-ports 8318*systemctl --user restart cliproxyapi.service*curl http://127.0.0.1:8317/*-D PREROUTING*docker rm -f cliproxyapi-standby*'
The output should include 'rules=0'
The path "$TEMP_HOME/.cli-proxy-api/config.standby.yaml" should not be exist
End

It 'gives the standby its own port'
cat >"$MOCK_BIN/docker" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "docker $*" >>"$MOCK_LOG"
if [ "$1" = run ]; then
  grep '^port:' "$HOME/.cli-proxy-api/config.standby.yaml" >>"$MOCK_LOG"
fi
EOF
When call run_swap
The status should be success
The output should include 'port: 8318'
End

It 'restarts in place without iptables access'
NO_SUDO=1
export NO_SUDO
When call run_swap
The status should be success
The output should include 'restarting cliproxyapi in place'
The output should include 'systemctl --user restart cliproxyapi.service'
The output should not include 'docker run'
End

It 'leaves the running server alone when the standby never starts'
STANDBY_DOWN=1
export STANDBY_DOWN
When call run_swap
The status should be failure
The output should include 'standby did not start on :8318'
The output should not include ' -I PREROUTING'
The output should not include 'systemctl --user restart'
The output should include 'docker rm -f cliproxyapi-standby'
End

It 'removes the redirect and standby when the unit does not come back'
MAIN_DOWN=1
export MAIN_DOWN
When call run_swap
The status should be failure
The output should include 'cliproxyapi did not come back on :8317'
The output should include 'rules=0'
The output should match pattern '*systemctl --user restart cliproxyapi.service*docker rm -f cliproxyapi-standby*'
End

It 'keeps the standby when the redirect cannot be removed'
DELETE_FAILS=1
export DELETE_FAILS
When call run_swap
The status should be failure
The output should include 'leaving cliproxyapi-standby running'
The output should not match pattern '*systemctl --user restart cliproxyapi.service*docker rm -f cliproxyapi-standby*'
End

It 'refuses a config without the expected port'
printf 'port: 9000\n' >"$TEMP_HOME/.cli-proxy-api/config.yaml"
When call run_swap
The status should be failure
The output should include 'does not declare port: 8317'
The output should not include 'docker run'
End

It 'routes the cliproxyapi image swap through the standby'
When run bash -c "sed -n '/^cliproxy-update:/,/^\$/p' Makefile"
The status should be success
The output should include 'home-manager/services/cliproxyapi/scripts/swap.sh'
End
End
