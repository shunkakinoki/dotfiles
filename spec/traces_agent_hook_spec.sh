#!/usr/bin/env bash

Describe 'traces agent hook guard'
GUARD="$PWD/config/shared/hooks/traces-agent-hook.sh"

setup() {
  TEMP_ROOT="$(mktemp -d)"
  TEMP_BIN="$TEMP_ROOT/bin"
  HOOK_LOG="$TEMP_ROOT/hook.log"
  PS_TABLE="$TEMP_ROOT/ps.txt"
  mkdir -p "$TEMP_BIN"
  : >"$PS_TABLE"
  cat >"$TEMP_BIN/traces" <<'STUB'
#!/usr/bin/env bash
printf 'args:%s\n' "$*" >>"$TRACES_HOOK_TEST_LOG"
printf 'stdin:%s\n' "$(cat)" >>"$TRACES_HOOK_TEST_LOG"
STUB
  cat >"$TEMP_BIN/ps" <<'STUB'
#!/usr/bin/env bash
cat "$TRACES_HOOK_TEST_PS_TABLE"
STUB
  chmod +x "$TEMP_BIN/traces" "$TEMP_BIN/ps"
  export TRACES_HOOK_TEST_LOG="$HOOK_LOG"
  export TRACES_HOOK_TEST_PS_TABLE="$PS_TABLE"
  export PATH="$TEMP_BIN:$PATH"
}

cleanup() {
  if [ -n "${UPLOAD_PID:-}" ]; then
    kill -KILL "$UPLOAD_PID" 2>/dev/null || true
  fi
  rm -rf "$TEMP_ROOT"
}

BeforeEach 'setup'
AfterEach 'cleanup'

start_fake_upload() {
  sleep 300 &
  UPLOAD_PID=$!
}

upload_row() {
  printf '%s %s /opt/traces/traces share --trace-id %s --source agent_hook --json\n' "$1" "$2" "$3" >>"$PS_TABLE"
}

run_guard() {
  printf '{"session_id":"%s"}' "$1" | "$GUARD" "$2" --agent claude-code
}

It 'passes session-start through with its payload'
When call run_guard trace-a session-start
The status should be success
The contents of file "$HOOK_LOG" should include 'args:hook agent session-start --agent claude-code'
The contents of file "$HOOK_LOG" should include 'stdin:{"session_id":"trace-a"}'
End

It 'skips prompt-submitted while the same trace is already uploading'
upload_row 4242 05:00 trace-a
When call run_guard trace-a prompt-submitted
The status should be success
The file "$HOOK_LOG" should not be exist
End

It 'skips agent-done when the per-user upload cap is reached'
upload_row 4001 00:10 trace-b
upload_row 4002 00:20 trace-c
upload_row 4003 00:30 trace-d
upload_row 4004 00:40 trace-e
When call run_guard trace-a agent-done
The status should be success
The file "$HOOK_LOG" should not be exist
End

It 'runs agent-done when other traces are uploading under the cap'
upload_row 4001 00:10 trace-b
upload_row 4002 00:20 trace-c
When call run_guard trace-a agent-done
The status should be success
The contents of file "$HOOK_LOG" should include 'args:hook agent agent-done --agent claude-code'
End

It 'terminates wedged uploads and does not count them toward the cap'
start_fake_upload
upload_row "$UPLOAD_PID" 1-02:03:04 trace-a
When call run_guard trace-a prompt-submitted
The status should be success
The contents of file "$HOOK_LOG" should include 'args:hook agent prompt-submitted --agent claude-code'
Assert sh -c "sleep 1; ! kill -0 $UPLOAD_PID 2>/dev/null"
End

It 'lets a session-end upload supersede the in-flight upload of the same trace'
start_fake_upload
upload_row "$UPLOAD_PID" 02:00 trace-a
When call run_guard trace-a session-end
The status should be success
The contents of file "$HOOK_LOG" should include 'args:hook agent session-end --agent claude-code'
Assert sh -c "sleep 1; ! kill -0 $UPLOAD_PID 2>/dev/null"
End

It 'honors the configured cap and stale age'
upload_row 4001 00:10 trace-b
upload_row 4002 00:20 trace-c
When call env TRACES_HOOK_MAX_INFLIGHT_UPLOADS=2 bash -c "printf '{\"session_id\":\"trace-a\"}' | '$GUARD' prompt-submitted --agent codex"
The status should be success
The file "$HOOK_LOG" should not be exist
End

It 'exits successfully when traces is not installed'
rm -f "$TEMP_BIN/traces"
When call env PATH="$TEMP_BIN:/usr/bin:/bin" bash -c "printf '{}' | '$GUARD' session-start --agent codex"
The status should be success
The file "$HOOK_LOG" should not be exist
End

It 'routes every agent traces hook through the guard'
When run bash -c "
  for config in \
    generated/hooks/moshi/claude/settings.json \
    generated/hooks/moshi/codex/hooks.json \
    generated/hooks/moshi/cursor/hooks.json \
    generated/hooks/moshi/grok/plugin/hooks/hooks.json \
    config/copilot/config.json; do
    for event in session-start prompt-submitted agent-done session-end; do
      jq -r '.. | objects | .command? // empty' \"\$config\" | grep -Fq \"\\\$HOME/dotfiles/config/shared/hooks/traces-agent-hook.sh \$event --agent \" || { echo \"missing \$event in \$config\"; exit 1; }
    done
  done
  jq -r '.. | objects | .command? // empty' config/antigravity/hooks.json | grep -Fq '\$HOME/dotfiles/config/shared/hooks/traces-agent-hook.sh agent-done --agent antigravity' || { echo 'missing antigravity'; exit 1; }
  for config in generated/hooks/moshi/claude/settings.json generated/hooks/moshi/codex/hooks.json generated/hooks/moshi/cursor/hooks.json generated/hooks/moshi/grok/plugin/hooks/hooks.json config/copilot/config.json config/antigravity/hooks.json; do
    if jq -r '.. | objects | .command? // empty' \"\$config\" | grep -Eq '(^|&& |; )traces hook agent'; then
      echo \"unguarded traces hook in \$config\"; exit 1
    fi
  done
"
The status should be success
End

It 'keeps the traces installer marker so hook install stays idempotent'
When run bash -c "jq -r '.. | objects | .command? // empty' generated/hooks/moshi/claude/settings.json | grep -F 'traces-agent-hook.sh' | grep -vFq '# traces hook agent' && exit 1 || exit 0"
The status should be success
End
End
