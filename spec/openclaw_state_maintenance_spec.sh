#!/usr/bin/env bash
# shellcheck disable=SC2329

Describe 'home-manager/services/openclaw/state-maintenance.sh'
SOURCE_SCRIPT="$PWD/home-manager/services/openclaw/state-maintenance.sh"

setup() {
  TEMP_DIR=$(mktemp -d)
  mkdir -p "$TEMP_DIR/.bun/bin" "$TEMP_DIR/bin" "$TEMP_DIR/.openclaw/state"
  touch "$TEMP_DIR/.openclaw/state/openclaw.sqlite"
  SCRIPT="$TEMP_DIR/maintenance.sh"
  sed 's|SYSTEMCTL=/usr/bin/systemctl|SYSTEMCTL=systemctl|' "$SOURCE_SCRIPT" >"$SCRIPT"
  printf '#!/usr/bin/env bash\nprintf "134217728\\n"\n' >"$TEMP_DIR/bin/stat"
  chmod +x "$TEMP_DIR/bin/stat"
  cat >"$TEMP_DIR/bin/systemctl" <<'EOF'
#!/usr/bin/env bash
echo "systemctl $*" >>"$HOME/calls.log"
if [ "$*" = "--user is-active openclaw-gateway.service" ]; then
  if [ -n "${GATEWAY_STATE:-}" ]; then echo "$GATEWAY_STATE";
  elif [ "${GATEWAY_ACTIVE_STATUS:-0}" = 0 ]; then echo active; else echo inactive; fi
  exit "${GATEWAY_ACTIVE_STATUS:-0}"
fi
exit 0
EOF
  cat >"$TEMP_DIR/.bun/bin/openclaw" <<'EOF'
#!/usr/bin/env bash
echo "openclaw $*" >>"$HOME/calls.log"
if [ "$1" = backup ]; then exit "${BACKUP_STATUS:-0}"; fi
if [ "$1" = doctor ]; then exit "${OPENCLAW_STATUS:-0}"; fi
exit 0
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

It 'keeps an active gateway running and skips offline maintenance'
When run env HOME="$TEMP_DIR" PATH="$TEMP_DIR/bin:$PATH" bash -c "bash '$SCRIPT'; cat '$TEMP_DIR/calls.log'"
The status should be success
The output should include 'gateway active; skipping offline maintenance'
The output should not include 'systemctl --user stop'
The output should not include 'systemctl --user start'
The output should not include 'openclaw backup'
The output should not include 'openclaw doctor'
End

It 'leaves an inactive gateway stopped'
When run env HOME="$TEMP_DIR" PATH="$TEMP_DIR/bin:$PATH" GATEWAY_ACTIVE_STATUS=3 bash -c "bash '$SCRIPT' >/dev/null && cat '$TEMP_DIR/calls.log'"
The status should be success
The output should not include 'systemctl --user start'
The output should not include 'stop openclaw-gateway.service'
The output should include "openclaw backup sqlite create --global --repository $TEMP_DIR/Backups/openclaw-sqlite"
The output should include 'openclaw doctor --state-sqlite compact --json'
End

It 'reports offline compaction failure without changing gateway state'
When run env HOME="$TEMP_DIR" PATH="$TEMP_DIR/bin:$PATH" GATEWAY_ACTIVE_STATUS=3 OPENCLAW_STATUS=1 bash -c "bash '$SCRIPT'; echo \"exit=\$?\"; cat '$TEMP_DIR/calls.log'"
The output should include 'state compaction failed'
The output should include 'exit=1'
The output should not include 'systemctl --user start'
The output should not include 'systemctl --user stop'
End

It 'refuses maintenance while gateway state is uncertain'
When run env HOME="$TEMP_DIR" PATH="$TEMP_DIR/bin:$PATH" GATEWAY_STATE=activating bash -c "bash '$SCRIPT'; echo \"exit=\$?\"; cat '$TEMP_DIR/calls.log'"
The output should include 'cannot read gateway state'
The output should include 'exit=1'
The output should not include 'openclaw backup'
The output should not include 'openclaw doctor'
End

It 'refuses offline compaction when the native snapshot fails'
When run env HOME="$TEMP_DIR" PATH="$TEMP_DIR/bin:$PATH" GATEWAY_ACTIVE_STATUS=3 BACKUP_STATUS=1 bash -c "bash '$SCRIPT'; echo \"exit=\$?\"; cat '$TEMP_DIR/calls.log'"
The output should include 'snapshot failed; skipping compaction'
The output should include 'exit=1'
The output should not include 'openclaw doctor'
End
End
