# shellcheck shell=bash
Describe 'Herdr integration activation'
SCRIPT="$PWD/config/herdr/install-integrations.sh"

setup() {
  TEMP_DIR=$(mktemp -d)
  cat >"$TEMP_DIR/herdr" <<'CLI'
#!/usr/bin/env bash
if [ "$1 $2" = 'integration status' ]; then
  cat "$HERDR_TEST_STATUS"
  exit "${HERDR_TEST_STATUS_EXIT:-0}"
fi
if [ "$1 $2" = 'integration install' ]; then
  printf 'install:%s\n' "$3"
fi
CLI
  chmod +x "$TEMP_DIR/herdr"
}

cleanup() {
  rm -rf "$TEMP_DIR"
}

Before 'setup'
After 'cleanup'

It 'does not rewrite integrations that are already current'
  printf 'codex: current (v8)\nopencode: current (v13)\n' >"$TEMP_DIR/status"
  When run env HERDR_TEST_STATUS="$TEMP_DIR/status" bash "$SCRIPT" "$TEMP_DIR/herdr"
  The status should be success
  The output should equal ''
End

It 'installs only an integration that is missing'
  printf 'codex: current (v8)\nopencode: not installed\n' >"$TEMP_DIR/status"
  When run env HERDR_TEST_STATUS="$TEMP_DIR/status" bash "$SCRIPT" "$TEMP_DIR/herdr"
  The status should be success
  The output should equal 'install:opencode'
End

It 'stops when integration status is unavailable'
  printf 'codex: current (v8)\nopencode: current (v13)\n' >"$TEMP_DIR/status"
  When run env HERDR_TEST_STATUS="$TEMP_DIR/status" HERDR_TEST_STATUS_EXIT=1 bash "$SCRIPT" "$TEMP_DIR/herdr"
  The status should not be success
  The output should equal ''
End
End
