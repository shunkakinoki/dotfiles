#!/usr/bin/env bash
# shellcheck disable=SC2329

Describe 'managed Codex daemon refresh'
setup() {
  TEST_ROOT=$(mktemp -d)
  export CODEX_LOG="$TEST_ROOT/codex.log"
  export MANAGED_CODEX_PATH="$TEST_ROOT/standalone/codex"
  mkdir -p "$TEST_ROOT/bin"
  touch "$CODEX_LOG"
  cat >"$TEST_ROOT/bin/codex" <<'MOCK'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$CODEX_LOG"
case "$*" in
  'app-server daemon version')
    if [ "${VERSION_STATUS:-0}" -ne 0 ]; then exit "$VERSION_STATUS"; fi
    printf '{"managedCodexPath":"%s"}\n' "$MANAGED_CODEX_PATH"
    ;;
  'app-server daemon restart') exit "${RESTART_STATUS:-0}" ;;
  *) exit 1 ;;
esac
MOCK
  chmod +x "$TEST_ROOT/bin/codex"
}

cleanup() { rm -rf "$TEST_ROOT"; }

refresh() {
  PATH="$TEST_ROOT/bin:$PATH" make --no-print-directory refresh-codex-daemon \
    DETECTED_HOST="${TEST_HOST:-kyber}" TAILSCALE_DNS_NAME= GIT_COMMIT_SHA=test
}

install_managed_binary() {
  mkdir -p "$(dirname "$MANAGED_CODEX_PATH")"
  touch "$MANAGED_CODEX_PATH"
}

Before 'setup'
After 'cleanup'

It 'preserves an externally owned app server when no standalone installation exists'
When call refresh
The status should be success
The output should include 'preserving the existing app server'
The contents of file "$CODEX_LOG" should eq 'app-server daemon version'
End

It 'refreshes and verifies an installed managed daemon'
install_managed_binary
When call refresh
The status should be success
The output should include 'daemon refreshed'
The contents of file "$CODEX_LOG" should eq 'app-server daemon version
app-server daemon restart
app-server daemon version'
End

It 'fails when daemon ownership information cannot be read'
export VERSION_STATUS=42
When call refresh
The status should be failure
The stderr should include 'Error'
The contents of file "$CODEX_LOG" should eq 'app-server daemon version'
End

It 'reports a failed managed restart'
install_managed_binary
export RESTART_STATUS=42
When call refresh
The status should be failure
The output should include 'Refreshing'
The stderr should include 'Error'
The contents of file "$CODEX_LOG" should eq 'app-server daemon version
app-server daemon restart'
End

It 'does not inspect or restart daemons on other hosts'
export TEST_HOST=matic
When call refresh
The status should be success
The output should include 'Kyber only'
The contents of file "$CODEX_LOG" should eq ''
End
End
