#!/usr/bin/env bash

Describe 'security.sh'
  SCRIPT="$PWD/config/claude/security.sh"

  setup() {
    TEMP_HOME=$(mktemp -d)
    ORIGINAL_HOME="$HOME"
    mkdir -p "$TEMP_HOME/.claude"
    cat > "$TEMP_HOME/.claude/settings.json" << 'SETTINGS'
{
  "permissions": {
    "deny": [
      "Bash(sudo:*)",
      "Bash(rm -rf /*:*)",
      "Bash(rm -rf ~/*:*)",
      "Bash(chmod -R 777:*)",
      "Bash(mkfs:*)",
      "Bash(dd if=:*)"
    ]
  }
}
SETTINGS
  }

  cleanup() {
    rm -rf "$TEMP_HOME"
  }

  Before 'setup'
  After 'cleanup'

  Describe 'tool filtering'
    It 'passes non-Bash tools through'
      Data '{"tool": {"name": "Read", "input": {}}}'
      When run bash -c "HOME='$TEMP_HOME' bash '$SCRIPT'"
      The status should be success
    End

    It 'passes when no tool specified'
      Data '{}'
      When run bash -c "HOME='$TEMP_HOME' bash '$SCRIPT'"
      The status should be success
    End
  End

  Describe 'safe commands'
    It 'allows ls -la'
      Data '{"tool": {"name": "Bash", "input": {"command": "ls -la"}}}'
      When run bash -c "HOME='$TEMP_HOME' bash '$SCRIPT'"
      The status should be success
    End

    It 'allows git status'
      Data '{"tool": {"name": "Bash", "input": {"command": "git status"}}}'
      When run bash -c "HOME='$TEMP_HOME' bash '$SCRIPT'"
      The status should be success
    End

    It 'allows cat /etc/hosts'
      Data '{"tool": {"name": "Bash", "input": {"command": "cat /etc/hosts"}}}'
      When run bash -c "HOME='$TEMP_HOME' bash '$SCRIPT'"
      The status should be success
    End

    It 'allows echo hello'
      Data '{"tool": {"name": "Bash", "input": {"command": "echo hello"}}}'
      When run bash -c "HOME='$TEMP_HOME' bash '$SCRIPT'"
      The status should be success
    End
  End

  Describe 'blocked commands'
    It 'blocks rm -rf /*'
      Data '{"tool": {"name": "Bash", "input": {"command": "rm -rf /*"}}}'
      When run bash -c "HOME='$TEMP_HOME' bash '$SCRIPT'"
      The status should eq 2
      The stderr should include 'BLOCKED'
    End
  End

  Describe 'edge cases'
    It 'passes with empty input'
      Data '{"tool": {"name": "Bash", "input": {}}}'
      When run bash -c "HOME='$TEMP_HOME' bash '$SCRIPT'"
      The status should be success
    End
  End
End
