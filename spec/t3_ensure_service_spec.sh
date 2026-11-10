#!/usr/bin/env bash
# shellcheck disable=SC2329,SC2016

Describe 'T3 activation service ownership'
SCRIPT="$PWD/home-manager/services/t3-connect/ensure-service.sh"
setup() {
  mock_bin_setup systemctl service-cli node
  export T3_SYSTEMCTL="$MOCK_BIN/systemctl"
  export T3_SERVICE_CLI="$MOCK_BIN/service-cli"
  export T3_CHECK_SERVICE=check-service.cjs
  cat >"$T3_SYSTEMCTL" <<'MOCK'
#!/usr/bin/env bash
printf 'systemctl %s\n' "$*" >>"$MOCK_LOG"
case "${2:-}" in
cat) [ "${MISSING_UNIT:-0}" = 0 ] ;;
is-failed) [ "${FAILED_UNIT:-0}" = 1 ] ;;
esac
MOCK
}
cleanup() {
  mock_bin_cleanup
  unset T3_SYSTEMCTL T3_SERVICE_CLI T3_CHECK_SERVICE MISSING_UNIT FAILED_UNIT
}
Before 'setup'
After 'cleanup'

It 'enables and verifies an installed service without reinstalling or restarting it'
When run bash "$SCRIPT"
The status should be success
The contents of file "$MOCK_LOG" should include 'systemctl --user enable --now t3code.service'
The contents of file "$MOCK_LOG" should include 'node check-service.cjs'
The contents of file "$MOCK_LOG" should not include 'service-cli'
The contents of file "$MOCK_LOG" should not include 'restart'
End

It 'bootstraps a missing unit through the repository-managed CLI'
export MISSING_UNIT=1
When run bash "$SCRIPT"
The status should be success
The contents of file "$MOCK_LOG" should include 'service-cli service install'
End

It 'clears a failed start limit before enabling the service'
export FAILED_UNIT=1
When run bash "$SCRIPT"
The status should be success
The contents of file "$MOCK_LOG" should include 'systemctl --user reset-failed t3code.service'
End

It 'propagates install failure before attempting readiness'
export MISSING_UNIT=1
printf '#!/usr/bin/env bash\nexit 23\n' >"$T3_SERVICE_CLI"
When run bash "$SCRIPT"
The status should equal 23
The contents of file "$MOCK_LOG" should not include 'node'
End

It 'reports an unmanaged owner without attempting to terminate it'
printf '#!/usr/bin/env bash\nexit 42\n' >"$MOCK_BIN/node"
When run bash "$SCRIPT"
The status should be success
The error should include 'continuing activation without taking it over'
The contents of file "$MOCK_LOG" should not include 'stop'
The contents of file "$MOCK_LOG" should not include 'restart'
End

It 'propagates other readiness failures'
printf '#!/usr/bin/env bash\nexit 41\n' >"$MOCK_BIN/node"
When run bash "$SCRIPT"
The status should equal 41
End
End
