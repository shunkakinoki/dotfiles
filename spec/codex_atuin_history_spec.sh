#!/usr/bin/env bash
# shellcheck disable=SC2329

Describe 'codex hooks/atuin-history.sh'
SCRIPT="$PWD/config/codex/hooks/atuin-history.sh"

Describe 'guard conditions'
  It 'exits on empty input'
  Data ''
  When run bash "$SCRIPT"
  The status should be success
  End

  It 'exits for non-Bash tools'
  Data '{"tool_name": "Read", "tool_input": {}}'
  When run bash "$SCRIPT"
  The status should be success
  End

  It 'exits for empty command'
  Data '{"tool_name": "Bash", "tool_input": {}}'
  When run bash "$SCRIPT"
  The status should be success
  End
End

Describe 'when atuin is installed'
  setup() {
    mock_bin_setup atuin
  }
  cleanup() {
    mock_bin_cleanup
  }
  Before 'setup'
  After 'cleanup'

  It 'records command in atuin'
  Data '{"tool_name": "Bash", "tool_input": {"command": "ls -la"}, "cwd": "/tmp"}'
  When run bash "$SCRIPT"
  The status should be success
  End
End
End
