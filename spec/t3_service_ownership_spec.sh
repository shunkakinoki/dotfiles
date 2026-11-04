#!/usr/bin/env bash
# shellcheck disable=SC2329,SC2016

Describe 'T3 serving process ownership'
SCRIPT="$PWD/home-manager/services/t3-connect/check-service.cjs"
setup() {
  T3_TEST_ROOT="$(mktemp -d)"
  export T3CODE_HOME="$T3_TEST_ROOT/t3" T3_PROC_ROOT="$T3_TEST_ROOT/proc"
  export T3_SERVICE_READY_TIMEOUT_MS=1
  mkdir -p "$T3CODE_HOME/userdata" "$T3_PROC_ROOT/$$"
  printf '{"pid":%s}\n' "$$" >"$T3CODE_HOME/userdata/server-runtime.json"
  printf '0::/user.slice/user@0.service/app.slice/t3code.service\n' >"$T3_PROC_ROOT/$$/cgroup"
  printf 'T3_SERVICE_LAUNCHER_CONTEXT={"protocol":3}\0' >"$T3_PROC_ROOT/$$/environ"
}
cleanup() {
  rm -rf "$T3_TEST_ROOT"
  unset T3CODE_HOME T3_PROC_ROOT T3_SERVICE_READY_TIMEOUT_MS
}
Before 'setup'
After 'cleanup'

It 'accepts a live server with launcher context inside the service'
When run node "$SCRIPT"
The status should be success
The output should include 'belongs to the managed launcher'
End

It 'rejects an SSH-session server even when it inherited launcher context'
printf '0::/user.slice/session-123.scope\n' >"$T3_PROC_ROOT/$$/cgroup"
When run node "$SCRIPT"
The status should be failure
The stderr should include 'outside the managed launcher'
End

It 'rejects a service process without the launcher IPC context'
printf 'T3_BOOT_SERVICE_UNIT=t3code.service\0' >"$T3_PROC_ROOT/$$/environ"
When run node "$SCRIPT"
The status should be failure
The stderr should include 'automatic updates are unavailable'
End

It 'rejects a missing runtime record instead of treating an active launcher as healthy'
rm -f "$T3CODE_HOME/userdata/server-runtime.json"
When run node "$SCRIPT"
The status should be failure
The stderr should include 'T3 service readiness failed'
End

It 'rejects a stale server PID'
printf '{"pid":2147483646}\n' >"$T3CODE_HOME/userdata/server-runtime.json"
When run node "$SCRIPT"
The status should be failure
The stderr should include 'T3 service readiness failed'
End

It 'waits for a runtime record published during service startup'
rm -f "$T3CODE_HOME/userdata/server-runtime.json"
export T3_SERVICE_READY_TIMEOUT_MS=3000
publish_record() {
  (
    sleep 0.3
    printf '{"pid":%s}\n' "$$" >"$T3CODE_HOME/userdata/server-runtime.json"
  ) &
  publisher=$!
  node "$SCRIPT"
  result=$?
  wait "$publisher"
  return "$result"
}
When call publish_record
The status should be success
The output should include 'belongs to the managed launcher'
End
End
