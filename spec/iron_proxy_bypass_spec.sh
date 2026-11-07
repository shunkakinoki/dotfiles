#!/usr/bin/env bash
# shellcheck disable=SC2016,SC2329

Describe 'nix-darwin/services/iron-proxy/bypass.sh'
SCRIPT="$PWD/nix-darwin/services/iron-proxy/bypass.sh"

setup_bypass() {
  TEST_DIR=$(mktemp -d)
  BIN="$TEST_DIR/bin"
  mkdir -p "$BIN"
  PF_LOG="$TEST_DIR/pfctl.log"
  : >"$PF_LOG"

  cat >"$BIN/pfctl" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$PF_LOG"
[ "$*" = "-q -a ironproxy-captive -f -" ] && cat >>"$PF_LOG"
exit "${PF_STATUS:-0}"
EOF
  printf '#!/usr/bin/env bash\necho 0\n' >"$BIN/id"
  cat >"$BIN/date" <<'EOF'
#!/usr/bin/env bash
case "$1" in
+%s) echo 1000 ;;
*) echo 00:00 ;;
esac
EOF
  chmod +x "$BIN"/*

  {
    printf 'set -euo pipefail\n'
    sed \
      -e "s|@guardStateDir@|$TEST_DIR/guard|g" \
      -e 's|@agentUid@|501|g' \
      "$SCRIPT"
  } >"$TEST_DIR/bypass.sh"
}

cleanup_bypass() {
  rm -rf "$TEST_DIR"
}

run_bypass() {
  env PATH="$BIN:$PATH" PF_LOG="$PF_LOG" PFCTL_BIN="$BIN/pfctl" PF_STATUS="${PF_STATUS:-0}" \
    bash "$TEST_DIR/bypass.sh" "$@"
}

Before 'setup_bypass'
After 'cleanup_bypass'

It 'opens a manual window and records it after the rule loads'
When call run_bypass 10
The output should include 'direct egress open for 10 minutes'
The contents of file "$TEST_DIR/guard/window" should equal 'manual 1600 -'
The contents of file "$TEST_DIR/guard/applied" should equal 'manual'
The contents of file "$PF_LOG" should include 'pass out quick proto { tcp udp } user 501'
End

It 'parses leading-zero minutes as base 10'
When call run_bypass 09
The output should include 'open for 9 minutes'
The contents of file "$TEST_DIR/guard/window" should equal 'manual 1540 -'
End

It 'rejects durations outside 1-60 minutes'
When call run_bypass 61
The status should equal 2
The stderr should include 'usage'
The path "$TEST_DIR/guard/window" should not be exist
End

It 'records no window when pfctl fails to load the rule'
BeforeCall 'PF_STATUS=1'
When call run_bypass 10
The status should be failure
The path "$TEST_DIR/guard/window" should not be exist
The path "$TEST_DIR/guard/applied" should not be exist
End

It 'keeps state when the off flush fails so the guard retries'
BeforeCall 'mkdir -p "$TEST_DIR/guard"; echo manual >"$TEST_DIR/guard/applied"; PF_STATUS=1'
When call run_bypass off
The status should be failure
The contents of file "$TEST_DIR/guard/applied" should equal 'manual'
End

It 'clears state after a successful off'
BeforeCall 'mkdir -p "$TEST_DIR/guard"; echo manual >"$TEST_DIR/guard/applied"'
When call run_bypass off
The output should equal 'direct egress closed'
The path "$TEST_DIR/guard/applied" should not be exist
End
End
