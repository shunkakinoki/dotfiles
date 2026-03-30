#!/usr/bin/env bash
# shellcheck disable=SC2329

Describe 'codex hooks/rtk-rewrite.sh'
SCRIPT="$PWD/config/codex/hooks/rtk-rewrite.sh"

Describe 'when rtk is not installed'
  It 'exits silently'
  Data '{"tool_name": "Bash", "tool_input": {"command": "git status"}}'
  When run bash -c "PATH=/usr/bin:/bin bash '$SCRIPT'"
  The status should be success
  The output should eq ''
  End
End

Describe 'when rtk is installed'
  setup() {
    mock_bin_setup rtk
  }
  cleanup() {
    mock_bin_cleanup
  }
  Before 'setup'
  After 'cleanup'

  It 'rewrites git status'
  Data '{"tool_name": "Bash", "tool_input": {"command": "git status"}}'
  When run bash "$SCRIPT"
  The status should be success
  The output should include 'rtk git status'
  End

  It 'rewrites cat to rtk read'
  Data '{"tool_name": "Bash", "tool_input": {"command": "cat README.md"}}'
  When run bash "$SCRIPT"
  The status should be success
  The output should include 'rtk read README.md'
  End

  It 'skips commands already using rtk'
  Data '{"tool_name": "Bash", "tool_input": {"command": "rtk git status"}}'
  When run bash "$SCRIPT"
  The status should be success
  The output should eq ''
  End

  It 'passes non-matching commands through'
  Data '{"tool_name": "Bash", "tool_input": {"command": "echo hello"}}'
  When run bash "$SCRIPT"
  The status should be success
  The output should eq ''
  End

  It 'exits silently with empty command'
  Data '{"tool_name": "Bash", "tool_input": {}}'
  When run bash "$SCRIPT"
  The status should be success
  The output should eq ''
  End
End
End
