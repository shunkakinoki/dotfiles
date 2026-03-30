#!/usr/bin/env bash
# shellcheck disable=SC2329

Describe 'codex hooks/rtk-rewrite.sh'
SCRIPT="$PWD/config/codex/hooks/rtk-rewrite.sh"

# Use real rtk if available, otherwise create a mock
if command -v rtk &>/dev/null && rtk rewrite "git status" >/dev/null 2>&1; then
  HAS_RTK_REWRITE=true
else
  HAS_RTK_REWRITE=false
  MOCK_BIN="$SHELLSPEC_TMPBASE/mock_bin_codex"
  mkdir -p "$MOCK_BIN"
  cat >"$MOCK_BIN/rtk" <<'MOCK'
#!/bin/bash
if [ "$1" = "rewrite" ]; then
  shift; CMD="$*"
  case "$CMD" in
    git\ *|ls\ *|ls) echo "rtk $CMD"; exit 0 ;;
    cat\ *) echo "rtk read ${CMD#cat }"; exit 0 ;;
    rtk\ *) echo "$CMD"; exit 0 ;;
    *) exit 1 ;;
  esac
elif [ "$1" = "--version" ]; then echo "rtk 0.34.0"
else exit 1; fi
MOCK
  chmod +x "$MOCK_BIN/rtk"
fi

run_hook() {
  if [ "$HAS_RTK_REWRITE" = true ]; then bash "$SCRIPT"
  else PATH="$MOCK_BIN:$PATH" bash "$SCRIPT"; fi
}

Describe 'guards'
It 'exits silently with empty command'
Data '{"tool_input": {}}'
When run run_hook
The status should be success
The output should eq ''
End
End

Describe 'rewrites'
It 'rewrites git status'
Data '{"tool_input": {"command": "git status"}}'
When run run_hook
The status should be success
The output should include 'rtk'
The output should include 'git status'
End

It 'passes non-matching commands through'
Data '{"tool_input": {"command": "echo hello"}}'
When run run_hook
The status should be success
The output should eq ''
End
End

End
