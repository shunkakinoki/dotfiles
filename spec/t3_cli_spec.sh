#!/usr/bin/env bash
# shellcheck disable=SC2329,SC2016

Describe 'T3 service CLI dispatch'
SCRIPT="$PWD/home-manager/services/t3-connect/cli.sh"

setup() {
  mock_bin_setup systemd-run
  T3_TEST_ROOT="$(mktemp -d)"
  export T3_TEST_ROOT
  export T3CODE_HOME="$T3_TEST_ROOT/t3"
  export T3_REAL_CLI="$MOCK_BIN/global-t3"
  export T3_SYSTEMD_RUN="$MOCK_BIN/systemd-run"
  export T3_PROC_CGROUP="$T3_TEST_ROOT/cgroup"
  unset T3_BOOT_SERVICE_UNIT
  printf '0::/user.slice/other.service\n' >"$T3_PROC_CGROUP"
  mkdir -p "$T3CODE_HOME/runtime/versions/1.2.3"
  printf '{"protocol":3,"activeVersion":"1.2.3"}\n' >"$T3CODE_HOME/runtime/service-state.json"
  cat >"$T3CODE_HOME/runtime/versions/1.2.3/t3" <<'MOCK'
#!/usr/bin/env bash
printf 'runtime\n' >>"$MOCK_LOG"
printf '<%s>\n' "$@" >>"$MOCK_LOG"
MOCK
  chmod +x "$T3CODE_HOME/runtime/versions/1.2.3/t3"
  cat >"$T3_REAL_CLI" <<'MOCK'
#!/usr/bin/env bash
printf 'global\n' >>"$MOCK_LOG"
MOCK
  chmod +x "$T3_REAL_CLI"
}
cleanup() {
  mock_bin_cleanup
  rm -rf "$T3_TEST_ROOT"
  unset T3_TEST_ROOT T3CODE_HOME T3_REAL_CLI T3_SYSTEMD_RUN T3_PROC_CGROUP T3_BOOT_SERVICE_UNIT
}
Before 'setup'
After 'cleanup'

It 'uses the active runtime instead of a stale global CLI and preserves arguments'
When run bash "$SCRIPT" project add '/tmp/project with spaces'
The status should be success
The contents of file "$MOCK_LOG" should include 'runtime'
The contents of file "$MOCK_LOG" should include '</tmp/project with spaces>'
The contents of file "$MOCK_LOG" should not include 'global'
End

serving_runtime() {
  mkdir -p "$T3CODE_HOME/runtime/versions/1.3.0" "$T3CODE_HOME/userdata"
  cat >"$T3CODE_HOME/runtime/versions/1.3.0/t3" <<'MOCK'
#!/usr/bin/env bash
printf 'serving\n' >>"$MOCK_LOG"
MOCK
  chmod +x "$T3CODE_HOME/runtime/versions/1.3.0/t3"
  printf '{"pid":%s,"serverVersion":"1.3.0"}\n' "$1" >"$T3CODE_HOME/userdata/server-runtime.json"
}

It 'uses the version the running server reports over a stale active version'
serving_runtime "$$"
When run bash "$SCRIPT" thread show --json t1
The status should be success
The contents of file "$MOCK_LOG" should include 'serving'
The contents of file "$MOCK_LOG" should not include 'runtime'
End

It 'falls back to the active version when the recorded server is gone'
serving_runtime 2147483646
When run bash "$SCRIPT" --version
The status should be success
The contents of file "$MOCK_LOG" should include 'runtime'
The contents of file "$MOCK_LOG" should not include 'serving'
End

It 'falls back to the active version when the serving runtime is not installed'
serving_runtime "$$"
rm -f "$T3CODE_HOME/runtime/versions/1.3.0/t3"
When run bash "$SCRIPT" --version
The status should be success
The contents of file "$MOCK_LOG" should include 'runtime'
End

It 'runs the serving release through npx when only the desktop app serves'
rm -f "$T3CODE_HOME/runtime/service-state.json"
serving_runtime "$$"
printf '#!/usr/bin/env bash\necho Darwin\n' >"$MOCK_BIN/uname"
printf '#!/usr/bin/env bash\nprintf "npx %%s\\n" "$*" >>"$MOCK_LOG"\n' >"$MOCK_BIN/npx"
chmod +x "$MOCK_BIN/uname" "$MOCK_BIN/npx"
When run bash "$SCRIPT" thread show --json t1
The status should be success
The contents of file "$MOCK_LOG" should include "npx --yes --prefix $T3CODE_HOME/runtime/npx t3@1.3.0 thread show --json t1"
The contents of file "$MOCK_LOG" should not include 'global'
End

It 'uses the managed package before any service runtime is installed'
rm -f "$T3CODE_HOME/runtime/service-state.json"
serving_runtime "$$"
When run bash "$SCRIPT" --version
The status should be success
The contents of file "$MOCK_LOG" should include 'global'
End

It 'rejects malformed state instead of invoking a potentially incompatible installer'
printf '{"activeVersion":"../../escape"}\n' >"$T3CODE_HOME/runtime/service-state.json"
When run bash "$SCRIPT" service install
The status should be failure
The stderr should include 'Invalid active T3 runtime version'
The contents of file "$MOCK_LOG" should equal ''
End

It 'fails closed when the recorded runtime is missing'
rm -f "$T3CODE_HOME/runtime/versions/1.2.3/t3"
When run bash "$SCRIPT" service install
The status should be failure
The stderr should include 'Active T3 runtime is unavailable'
The contents of file "$MOCK_LOG" should equal ''
End

It 'preserves the working directory for a delegated relative T3 home'
export T3_BOOT_SERVICE_UNIT=t3code.service
When run bash "$SCRIPT" service install --base-dir ./t3-home
The status should be success
The output should include 'T3 service operation queued'
The contents of file "$MOCK_LOG" should include "--working-directory=$PWD"
The contents of file "$MOCK_LOG" should include 'service install --base-dir ./t3-home'
End

It 'delegates the legacy service update command'
export T3_BOOT_SERVICE_UNIT=t3code.service
When run bash "$SCRIPT" service update
The status should be success
The output should include 'T3 service operation queued'
The contents of file "$MOCK_LOG" should include 'service update'
End

It 'preserves the explicit consent requirement for top-level uninstall'
export T3_BOOT_SERVICE_UNIT=t3code.service
When run bash "$SCRIPT" uninstall
The status should be success
The output should include 'T3 service operation queued'
The contents of file "$MOCK_LOG" should not include '--yes'
End

It 'runs an external updater synchronously'
When run bash "$SCRIPT" update 1.2.4 --yes
The status should be success
The contents of file "$MOCK_LOG" should include '<update>'
The contents of file "$MOCK_LOG" should not include 'systemd-run'
End

It 'delegates an in-service update to an independent unit with restart consent'
export T3_BOOT_SERVICE_UNIT=t3code.service
When run bash "$SCRIPT" update 1.2.4
The status should be success
The output should include 'T3 service operation queued'
The contents of file "$MOCK_LOG" should include '--user --collect --no-block'
The contents of file "$MOCK_LOG" should include '--setenv=T3_BOOT_SERVICE_UNIT='
The contents of file "$MOCK_LOG" should include 'update 1.2.4 --yes'
The contents of file "$MOCK_LOG" should not include 'runtime'
End

It 'detects the service cgroup when a shell dropped its environment marker'
printf '0::/user.slice/user@0.service/app.slice/t3code.service\n' >"$T3_PROC_CGROUP"
When run bash "$SCRIPT" service restart
The status should be success
The output should include 'T3 service operation queued'
The contents of file "$MOCK_LOG" should include 'service restart'
The contents of file "$MOCK_LOG" should not include '--yes'
The contents of file "$MOCK_LOG" should not include 'runtime'
End

It 'keeps ordinary CLI queries synchronous inside the service'
export T3_BOOT_SERVICE_UNIT=t3code.service
When run bash "$SCRIPT" service status
The status should be success
The contents of file "$MOCK_LOG" should include '<status>'
The contents of file "$MOCK_LOG" should not include 'systemd-run'
End

It 'propagates a failed delegation instead of reporting it queued'
export T3_BOOT_SERVICE_UNIT=t3code.service
printf '#!/usr/bin/env bash\nexit 23\n' >"$T3_SYSTEMD_RUN"
When run bash "$SCRIPT" service install
The status should equal 23
The output should equal ''
End
End
