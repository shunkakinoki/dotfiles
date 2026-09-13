#!/usr/bin/env bash
Describe 'optional systemd service restart targets'

setup() {
  TEST_ROOT=$(mktemp -d)
  cat >"$TEST_ROOT/systemctl" <<'EOF'
#!/usr/bin/env bash
if [ "${2:-}" = show ]; then
  printf '%s\n' "${UNIT_STATE:-not-found}"
else
  printf '%s\n' "$*" >>"$RESTART_LOG"
  exit "${RESTART_RESULT:-0}"
fi
EOF
  chmod +x "$TEST_ROOT/systemctl"
}
cleanup() { rm -rf "$TEST_ROOT"; }
Before setup
After cleanup

It 'skips an optional service that is not installed'
When run env PATH="$TEST_ROOT:$PATH" UNIT_STATE=not-found RESTART_LOG="$TEST_ROOT/restarts" make systemctl-ollama HOST=kamino1 DETECTED_HOST=kamino1
The status should be success
The output should include 'Skipping ollama.service'
The path "$TEST_ROOT/restarts" should not be exist
End

It 'restarts an installed optional service'
When run env PATH="$TEST_ROOT:$PATH" UNIT_STATE=loaded RESTART_RESULT=0 RESTART_LOG="$TEST_ROOT/restarts" make systemctl-ollama HOST=kamino1 DETECTED_HOST=kamino1
The status should be success
The contents of file "$TEST_ROOT/restarts" should include '--user restart ollama.service'
The output should include 'ollama restarted'
End

It 'surfaces restart failures'
When run env PATH="$TEST_ROOT:$PATH" UNIT_STATE=loaded RESTART_RESULT=3 RESTART_LOG="$TEST_ROOT/restarts" make systemctl-ollama HOST=kamino1 DETECTED_HOST=kamino1
The status should be failure
The error should include 'Error 3'
End
End
