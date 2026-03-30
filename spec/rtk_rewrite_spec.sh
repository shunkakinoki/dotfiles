#!/usr/bin/env bash
# shellcheck disable=SC2329

Describe 'rtk-rewrite.sh'
SCRIPT="$PWD/config/claude/hooks/rtk-rewrite.sh"

# Use real rtk if available, otherwise create a mock that simulates basic rewrites
if command -v rtk &>/dev/null && rtk rewrite "git status" >/dev/null 2>&1; then
  HAS_RTK_REWRITE=true
else
  HAS_RTK_REWRITE=false
  MOCK_BIN="$SHELLSPEC_TMPBASE/mock_bin"
  mkdir -p "$MOCK_BIN"
  # Mock rtk that simulates basic rewrite behavior
  cat >"$MOCK_BIN/rtk" <<'MOCK'
#!/bin/bash
if [ "$1" = "rewrite" ]; then
  shift
  CMD="$*"
  case "$CMD" in
    git\ *|cargo\ *|ls\ *|ls) echo "rtk $CMD"; exit 0 ;;
    cat\ *) echo "rtk read ${CMD#cat }"; exit 0 ;;
    curl\ *|find\ *|grep\ *|diff\ *|tree\ *|wget\ *) echo "rtk $CMD"; exit 0 ;;
    pytest\ *|pytest|ruff\ *|pip\ *) echo "rtk $CMD"; exit 0 ;;
    go\ test\ *|go\ build\ *|go\ vet\ *) echo "rtk $CMD"; exit 0 ;;
    gh\ pr\ *|gh\ issue\ *|gh\ run\ *) echo "rtk $CMD"; exit 0 ;;
    vitest\ *|vitest) echo "rtk $CMD"; exit 0 ;;
    docker\ *|kubectl\ *) echo "rtk $CMD"; exit 0 ;;
    rtk\ *) echo "$CMD"; exit 0 ;;
    *) exit 1 ;;
  esac
elif [ "$1" = "--version" ]; then
  echo "rtk 0.34.0"
else
  exit 1
fi
MOCK
  chmod +x "$MOCK_BIN/rtk"
fi

run_hook() {
  if [ "$HAS_RTK_REWRITE" = true ]; then
    bash "$SCRIPT"
  else
    PATH="$MOCK_BIN:$PATH" bash "$SCRIPT"
  fi
}

run_hook_jq() {
  if [ "$HAS_RTK_REWRITE" = true ]; then
    bash "$SCRIPT" | jq -r '.hookSpecificOutput.updatedInput.command'
  else
    PATH="$MOCK_BIN:$PATH" bash "$SCRIPT" | jq -r '.hookSpecificOutput.updatedInput.command'
  fi
}

Describe 'guards'
It 'exits silently when no command in input'
Data '{"tool_input": {}}'
When run run_hook
The status should be success
The output should eq ''
End

It 'exits silently for empty command'
Data '{"tool_input": {"command": ""}}'
When run run_hook
The status should be success
The output should eq ''
End
End

Describe 'skip conditions'
It 'skips heredoc commands'
Data '{"tool_input": {"command": "cat <<EOF\nhello\nEOF"}}'
When run run_hook
The status should be success
The output should eq ''
End
End

Describe 'rewrites'
It 'rewrites git status'
Data '{"tool_input": {"command": "git status"}}'
When run run_hook_jq
The status should be success
The output should include 'rtk'
The output should include 'git status'
End

It 'rewrites ls'
Data '{"tool_input": {"command": "ls -la"}}'
When run run_hook_jq
The status should be success
The output should include 'rtk'
End

It 'passes non-matching commands through'
Data '{"tool_input": {"command": "echo hello"}}'
When run run_hook
The status should be success
The output should eq ''
End
End

Describe 'output format'
It 'outputs valid JSON with hookSpecificOutput'
Data '{"tool_input": {"command": "git status"}}'
When run run_hook
The status should be success
The output should include '"hookSpecificOutput"'
The output should include '"PreToolUse"'
End

It 'preserves original tool_input fields'
Data '{"tool_input": {"command": "git status", "timeout": 5000}}'
When run run_hook
The status should be success
The output should include '"timeout"'
The output should include '5000'
End
End

End
