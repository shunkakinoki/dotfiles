#!/usr/bin/env bash
# shellcheck disable=SC2016,SC2329

Describe 'git-ai-checkpoint.sh'
SCRIPT="$PWD/config/shared/hooks/git-ai-checkpoint.sh"

setup() {
  FAKE_BIN=$(mktemp -d)
  cat >"$FAKE_BIN/git-ai" <<'EOF'
#!/usr/bin/env bash
echo "args: $*"
echo "stdin: $(cat)"
exit "${FAKE_GIT_AI_STATUS:-0}"
EOF
  chmod +x "$FAKE_BIN/git-ai"
}

setup_hung() {
  FAKE_BIN=$(mktemp -d)
  cat >"$FAKE_BIN/git-ai" <<'EOF'
#!/usr/bin/env bash
sleep 30 &
echo $! >"$FAKE_CHILD_PID_FILE"
wait
EOF
  chmod +x "$FAKE_BIN/git-ai"
  FAKE_CHILD_PID_FILE="$FAKE_BIN/child.pid"
  export FAKE_CHILD_PID_FILE
}

cleanup() {
  rm -rf "$FAKE_BIN"
}

After 'cleanup'

Describe 'with a responsive git-ai'
Before 'setup'

It 'passes the preset and the hook payload through'
Data '{"tool_input": {"file_path": "a.txt"}}'
When run env PATH="$FAKE_BIN:$PATH" bash "$SCRIPT" claude
The status should be success
The output should include 'args: checkpoint claude --hook-input stdin'
The output should include 'stdin: {"tool_input": {"file_path": "a.txt"}}'
End

It 'keeps the exit status of git-ai'
Data '{}'
When run env PATH="$FAKE_BIN:$PATH" FAKE_GIT_AI_STATUS=3 bash "$SCRIPT" droid
The status should equal 3
The output should include 'args: checkpoint droid'
End
End

Describe 'with a hung git-ai'
Before 'setup_hung'

child_is_gone() {
  ! kill -0 "$(cat "$FAKE_CHILD_PID_FILE")" 2>/dev/null
}

It 'stops the checkpoint and its children at the limit'
Data '{}'
When run env PATH="$FAKE_BIN:$PATH" GIT_AI_CHECKPOINT_TIMEOUT=1 bash "$SCRIPT" gemini
The status should be success
The error should include 'exceeded 1s'
Assert child_is_gone
End
End

Describe 'without git-ai'
setup_empty() {
  FAKE_BIN=$(mktemp -d)
}
Before 'setup_empty'

It 'exits quietly'
Data '{}'
When run env PATH="/usr/bin:/bin" HOME="$FAKE_BIN" /bin/bash "$SCRIPT" cursor
The status should be success
The output should equal ''
End
End
End
