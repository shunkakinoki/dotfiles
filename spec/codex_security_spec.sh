#!/usr/bin/env bash
# shellcheck disable=SC2329

Describe 'codex hooks/security.sh'
SCRIPT="$PWD/config/codex/hooks/security.sh"

Describe 'tool filtering'
It 'passes non-Bash tools through'
Data '{"tool_name": "Read", "tool_input": {}}'
When run bash "$SCRIPT"
The status should be success
End

It 'passes when no tool specified'
Data '{}'
When run bash "$SCRIPT"
The status should be success
End
End

Describe 'safe commands'
It 'allows ls -la'
Data '{"tool_name": "Bash", "tool_input": {"command": "ls -la"}}'
When run bash "$SCRIPT"
The status should be success
End

It 'allows git status'
Data '{"tool_name": "Bash", "tool_input": {"command": "git status"}}'
When run bash "$SCRIPT"
The status should be success
End
End

Describe 'blocked commands'
It 'blocks rm -rf /*'
Data '{"tool_name": "Bash", "tool_input": {"command": "rm -rf /*"}}'
When run bash "$SCRIPT"
The status should eq 2
The stderr should include 'BLOCKED'
End

It 'blocks sudo'
Data '{"tool_name": "Bash", "tool_input": {"command": "sudo rm -rf /"}}'
When run bash "$SCRIPT"
The status should eq 2
The stderr should include 'BLOCKED'
End

It 'blocks hidden dangerous command after semicolon'
Data '{"tool_name": "Bash", "tool_input": {"command": "echo ok; rm -rf /*"}}'
When run bash "$SCRIPT"
The status should eq 2
The stderr should include 'BLOCKED'
End

It 'blocks dd if='
Data '{"tool_name": "Bash", "tool_input": {"command": "dd if=/dev/zero of=/tmp/zero bs=1 count=1"}}'
When run bash "$SCRIPT"
The status should eq 2
The stderr should include 'BLOCKED'
End
End

Describe 'edge cases'
It 'passes with empty command'
Data '{"tool_name": "Bash", "tool_input": {}}'
When run bash "$SCRIPT"
The status should be success
End
End
End
