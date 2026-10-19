#!/usr/bin/env bash
# shellcheck disable=SC2016,SC2329

Describe 'screenshot clipboard service recovery'
SCRIPT="$PWD/home-manager/services/screenshot-clipboard/ensure-loaded.sh"

setup() {
  TEST_ROOT=$(mktemp -d)
  mkdir -p "$TEST_ROOT/bin" "$TEST_ROOT/home/Library/LaunchAgents"
  export SERVICE_TEST_ROOT="$TEST_ROOT"
  export SERVICE_TEST_LOG="$TEST_ROOT/launchctl.log"
  export XDG_STATE_HOME="$TEST_ROOT/state"
  mkdir -p "$XDG_STATE_HOME/screenshot-clipboard"
  touch "$SERVICE_TEST_LOG"
  touch "$TEST_ROOT/home/Library/LaunchAgents/org.nix-community.home.screenshot-clipboard.plist"
  cat >"$TEST_ROOT/bin/launchctl" <<'MOCK'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$SERVICE_TEST_LOG"
case "$1" in
  enable) exit 0 ;;
  print)
    [[ -f "$SERVICE_TEST_ROOT/loaded" ]] || exit 1
    if [[ -f "$SERVICE_TEST_ROOT/running" ]]; then
      printf '\tpid = 123\n'
    fi
    ;;
  bootstrap)
    [[ ${BOOTSTRAP_FAIL:-0} == 0 ]] || { echo 'bootstrap rejected' >&2; exit 5; }
    touch "$SERVICE_TEST_ROOT/loaded"
    ;;
  kickstart)
    [[ ${KICKSTART_FAIL:-0} == 0 ]] || { echo 'kickstart rejected' >&2; exit 5; }
    if [[ ${NEVER_RUNNING:-0} == 0 ]]; then touch "$SERVICE_TEST_ROOT/running"; fi
    if [[ ${NEVER_READY:-0} == 0 ]]; then printf '123' >"$XDG_STATE_HOME/screenshot-clipboard/ready-pid"; fi
    ;;
  *) exit 99 ;;
esac
MOCK
  printf '#!/usr/bin/env bash\nexit 0\n' >"$TEST_ROOT/bin/sleep"
  chmod +x "$TEST_ROOT/bin/launchctl" "$TEST_ROOT/bin/sleep"
}

cleanup() { rm -rf "$TEST_ROOT"; }

recover() {
  HOME="$TEST_ROOT/home" PATH="$TEST_ROOT/bin:$PATH" bash "$SCRIPT"
}

Before 'setup'
After 'cleanup'

It 'registers and starts an enabled but unloaded agent'
When call recover
The status should be success
The output should eq 'Screenshot clipboard watcher is running'
The contents of file "$SERVICE_TEST_LOG" should include "bootstrap gui/$(id -u) $TEST_ROOT/home/Library/LaunchAgents/org.nix-community.home.screenshot-clipboard.plist"
The path "$TEST_ROOT/running" should be exist
End

It 'preserves a loaded watcher and does not bootstrap it again'
touch "$TEST_ROOT/loaded" "$TEST_ROOT/running"
When call recover
The status should be success
The output should eq 'Screenshot clipboard watcher is running'
The contents of file "$SERVICE_TEST_LOG" should not include 'bootstrap'
The contents of file "$SERVICE_TEST_LOG" should not include 'bootout'
End

It 'starts a registered but stopped watcher'
touch "$TEST_ROOT/loaded"
When call recover
The status should be success
The output should eq 'Screenshot clipboard watcher is running'
The path "$TEST_ROOT/running" should be exist
End

It 'reports a missing plist without changing launchd'
rm -f "$TEST_ROOT/home/Library/LaunchAgents/org.nix-community.home.screenshot-clipboard.plist"
When call recover
The status should be failure
The stderr should include 'activate Home Manager first'
The contents of file "$SERVICE_TEST_LOG" should eq ''
End

It 'reports bootstrap failure instead of claiming success'
export BOOTSTRAP_FAIL=1
When call recover
The status should be failure
The stderr should eq 'bootstrap rejected'
The contents of file "$SERVICE_TEST_LOG" should not include 'kickstart'
End

It 'reports kickstart failure instead of claiming success'
export KICKSTART_FAIL=1
When call recover
The status should be failure
The stderr should eq 'kickstart rejected'
End

It 'requires a running process after an accepted start request'
export NEVER_RUNNING=1
When call recover
The status should be failure
The stderr should include 'watcher did not become ready'
End

It 'rejects a running process that has not registered its watch'
export NEVER_READY=1
When call recover
The status should be failure
The stderr should include 'watcher did not become ready'
End

It 'rejects readiness left behind by an earlier process'
touch "$TEST_ROOT/loaded" "$TEST_ROOT/running"
printf '999' >"$XDG_STATE_HOME/screenshot-clipboard/ready-pid"
export NEVER_READY=1
When call recover
The status should be failure
The stderr should include 'watcher did not become ready'
End

It 'includes screenshot recovery in the normal service refresh'
When run make --no-print-directory --dry-run launchctl TAILSCALE_DNS_NAME= GIT_COMMIT_SHA=test
The status should be success
The line 1 should eq 'bash home-manager/services/screenshot-clipboard/ensure-loaded.sh'
End
End
