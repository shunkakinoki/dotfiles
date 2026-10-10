#!/usr/bin/env bash
# shellcheck disable=SC2329,SC2016

Describe 'T3 browser host setup'
SCRIPT="$PWD/home-manager/services/t3-connect/setup-browser.sh"

setup() {
  mock_bin_setup id sudo browser-cli
  : "${MOCK_BIN:?}"
  T3_BROWSER_TEST_ROOT="$(mktemp -d)"
  export T3_BROWSER_TEST_ROOT
  export T3_REAL_CLI="$T3_BROWSER_TEST_ROOT/t3"
  export T3_BROWSER_CLI="$MOCK_BIN/browser-cli"
  export T3CODE_HOME="$T3_BROWSER_TEST_ROOT/custom home"
  export MOCK_UID=0
  touch "$T3_REAL_CLI"
  chmod +x "$T3_REAL_CLI"
  cat >"$MOCK_BIN/id" <<'MOCK'
#!/usr/bin/env bash
echo "$MOCK_UID"
MOCK
  cat >"$MOCK_BIN/sudo" <<'MOCK'
#!/usr/bin/env bash
printf 'sudo %s\n' "$1" >>"$MOCK_LOG"
[ "${MOCK_PRIVILEGE_EXIT:-0}" = 0 ] || exit "$MOCK_PRIVILEGE_EXIT"
shift
exec "$@"
MOCK
  cat >"$MOCK_BIN/browser-cli" <<'MOCK'
#!/usr/bin/env bash
printf 'args=%s\nhome=%s\nbase=%s\npath=%s\nfrontend=%s\n' "$*" "$HOME" "$T3CODE_HOME" "$PATH" "$DEBIAN_FRONTEND" >>"$MOCK_LOG"
exit "${MOCK_BROWSER_EXIT:-0}"
MOCK
}

cleanup() {
  mock_bin_cleanup
  rm -rf "$T3_BROWSER_TEST_ROOT"
  unset T3_BROWSER_TEST_ROOT T3_REAL_CLI T3_BROWSER_CLI T3CODE_HOME MOCK_UID MOCK_PRIVILEGE_EXIT MOCK_BROWSER_EXIT
}

Before 'setup'
After 'cleanup'

It 'runs setup directly as root with the invoking home and PATH'
When run bash "$SCRIPT"
The status should be success
The contents of file "$MOCK_LOG" should include 'args=browser setup'
The contents of file "$MOCK_LOG" should include "home=$HOME"
The contents of file "$MOCK_LOG" should include "base=$T3CODE_HOME"
The contents of file "$MOCK_LOG" should include "path=$PATH"
The contents of file "$MOCK_LOG" should include 'frontend=noninteractive'
The contents of file "$MOCK_LOG" should not include 'sudo'
End

It 'uses noninteractive privilege escalation for a regular user'
export MOCK_UID=1000
When run bash "$SCRIPT"
The status should be success
The contents of file "$MOCK_LOG" should include 'sudo -n'
The contents of file "$MOCK_LOG" should include 'args=browser setup'
The contents of file "$MOCK_LOG" should include "home=$HOME"
The contents of file "$MOCK_LOG" should include "base=$T3CODE_HOME"
The contents of file "$MOCK_LOG" should include "path=$PATH"
End

It 'defaults to the invoking user T3 home'
unset T3CODE_HOME
When run bash "$SCRIPT"
The status should be success
The contents of file "$MOCK_LOG" should include "base=$HOME/.t3"
End

It 'defers setup until managed packages are installed'
rm -f "$T3_REAL_CLI"
When run bash "$SCRIPT"
The status should be success
The output should include 'deferring browser setup'
The contents of file "$MOCK_LOG" should eq ''
End

It 'uses the dispatcher when an active runtime exists without a global CLI'
rm -f "$T3_REAL_CLI"
mkdir -p "$T3CODE_HOME/runtime"
printf '{}\n' >"$T3CODE_HOME/runtime/service-state.json"
When run bash "$SCRIPT"
The status should be success
The contents of file "$MOCK_LOG" should include 'args=browser setup'
End

It 'reports a root setup failure'
export MOCK_BROWSER_EXIT=23
When run bash "$SCRIPT"
The status should equal 23
End

It 'selects the active service CLI through the real dispatcher'
export T3_BROWSER_CLI="$T3_BROWSER_TEST_ROOT/dispatcher"
cp "$PWD/home-manager/services/t3-connect/cli.sh" "$T3_BROWSER_CLI"
chmod +x "$T3_BROWSER_CLI"
mkdir -p "$T3CODE_HOME/runtime/versions/1.2.3"
printf '{"activeVersion":"1.2.3"}\n' >"$T3CODE_HOME/runtime/service-state.json"
cp "$MOCK_BIN/browser-cli" "$T3CODE_HOME/runtime/versions/1.2.3/t3"
printf '#!/usr/bin/env bash\nexit 99\n' >"$T3_REAL_CLI"
When run bash "$SCRIPT"
The status should be success
The contents of file "$MOCK_LOG" should include 'args=browser setup'
End

It 'reports a setup failure after privilege escalation'
export MOCK_UID=1000 MOCK_BROWSER_EXIT=23
When run bash "$SCRIPT"
The status should equal 23
End

It 'fails without prompting when privilege escalation is unavailable'
export MOCK_UID=1000 MOCK_PRIVILEGE_EXIT=1
When run bash "$SCRIPT"
The status should equal 1
The contents of file "$MOCK_LOG" should include 'sudo -n'
The contents of file "$MOCK_LOG" should not include 'args='
End

It 'runs upstream setup on every reconciliation'
When run bash -c 'bash "$1" && bash "$1"' _ "$SCRIPT"
The status should be success
The contents of file "$MOCK_LOG" should include "$(printf 'frontend=noninteractive\nargs=browser setup')"
End
End
