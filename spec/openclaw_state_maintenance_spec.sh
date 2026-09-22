#!/usr/bin/env bash
# shellcheck disable=SC2329

Describe 'home-manager/services/openclaw/state-maintenance.sh'
SCRIPT="$PWD/home-manager/services/openclaw/state-maintenance.sh"

setup() {
  TEMP_DIR=$(mktemp -d)
  mkdir -p "$TEMP_DIR/.bun/bin" "$TEMP_DIR/bin"
  cat >"$TEMP_DIR/bin/systemctl" <<'EOF'
#!/usr/bin/env bash
echo "systemctl $*" >>"$HOME/calls.log"
[ "$*" = "--user is-active --quiet openclaw-gateway.service" ] && exit "${GATEWAY_ACTIVE_STATUS:-0}"
exit 0
EOF
  cat >"$TEMP_DIR/.bun/bin/openclaw" <<'EOF'
#!/usr/bin/env bash
echo "openclaw $*" >>"$HOME/calls.log"
exit "${OPENCLAW_STATUS:-0}"
EOF
  chmod +x "$TEMP_DIR/bin/systemctl" "$TEMP_DIR/.bun/bin/openclaw"
}
cleanup() { rm -rf "$TEMP_DIR"; }
BeforeEach 'setup'
AfterEach 'cleanup'

It 'passes bash syntax check'
When run bash -n "$SCRIPT"
The status should be success
End

It 'fails when the openclaw binary is missing'
rm "$TEMP_DIR/.bun/bin/openclaw"
When run env HOME="$TEMP_DIR" PATH="$TEMP_DIR/bin:$PATH" bash "$SCRIPT"
The status should be failure
The output should include 'openclaw binary missing'
End

It 'stops the running gateway for maintenance and restarts it'
When run env HOME="$TEMP_DIR" PATH="$TEMP_DIR/bin:$PATH" bash -c "bash '$SCRIPT' >/dev/null && cat '$TEMP_DIR/calls.log'"
The status should be success
The line 2 of output should equal 'systemctl --user stop openclaw-gateway.service'
The line 3 of output should equal 'openclaw tasks maintenance --apply'
The line 4 of output should equal 'systemctl --user start openclaw-gateway.service'
End

It 'leaves an inactive gateway stopped'
When run env HOME="$TEMP_DIR" PATH="$TEMP_DIR/bin:$PATH" GATEWAY_ACTIVE_STATUS=3 bash -c "bash '$SCRIPT' >/dev/null && cat '$TEMP_DIR/calls.log'"
The status should be success
The output should not include 'systemctl --user start'
The output should not include 'stop openclaw-gateway.service'
End

It 'reports failure but still restarts the gateway when maintenance fails'
When run env HOME="$TEMP_DIR" PATH="$TEMP_DIR/bin:$PATH" OPENCLAW_STATUS=1 bash -c "bash '$SCRIPT'; echo \"exit=\$?\"; cat '$TEMP_DIR/calls.log'"
The output should include 'tasks maintenance failed'
The output should include 'exit=1'
The output should include 'systemctl --user start openclaw-gateway.service'
End
End
