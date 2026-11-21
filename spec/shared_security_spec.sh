#!/usr/bin/env bash
# shellcheck disable=SC2329

Describe 'shared hooks/security.sh'
SCRIPT="$PWD/config/shared/hooks/security.sh"

Describe 'tool filtering'
It 'passes non-Bash tools through'
Data '{"tool_name": "Read", "tool_input": {}}'
When run bash "$SCRIPT"
The status should be success
End

It 'passes non-shell Copilot tools through'
Data '{"toolName": "read", "toolArgs": {"command": "sudo rm -rf /"}}'
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
galactica_switch="sudo -n env HOMEBREW_NO_AUTO_UPDATE=1 HOST=galactica HOSTNAME=galactica NIXPKGS_ALLOW_UNFREE=1 /run/current-system/sw/bin/darwin-rebuild switch --flake $HOME/dotfiles#galactica --impure --no-update-lock-file"

check_command() {
  uname() { printf '%s\n' "$SECURITY_TEST_OS"; }
  scutil() { printf '%s\n' "$SECURITY_TEST_HOST"; }
  export -f uname scutil
  jq -n --arg command "$1" '{tool_name: "Bash", tool_input: {command: $command}}' |
    SECURITY_TEST_OS="${2:-Darwin}" SECURITY_TEST_HOST="${3:-galactica}" bash "$SCRIPT"
}

It 'allows the exact noninteractive Galactica activation'
When call check_command "$galactica_switch"
The status should be success
End

It 'blocks the Galactica activation on Linux'
When call check_command "$galactica_switch" Linux galactica
The status should eq 2
The stderr should include 'BLOCKED'
End

It 'blocks the Galactica activation on another Darwin host'
When call check_command "$galactica_switch" Darwin other-host
The status should eq 2
The stderr should include 'BLOCKED'
End

It 'blocks extra root command arguments on the Galactica exception'
When call check_command "$galactica_switch --help"
The status should eq 2
The stderr should include 'BLOCKED'
End

It 'blocks a different flake on the Galactica exception'
When call check_command "${galactica_switch/dotfiles#galactica/other#galactica}"
The status should eq 2
The stderr should include 'BLOCKED'
End

It 'blocks chained privileged commands after the permitted activation'
When call check_command "$galactica_switch && sudo rm -rf /"
The status should eq 2
The stderr should include 'BLOCKED'
End

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

It 'blocks Copilot shell input with object toolArgs'
Data '{"toolName": "shell", "toolArgs": {"command": "sudo rm -rf /"}}'
When run bash "$SCRIPT"
The status should eq 2
The stderr should include 'BLOCKED'
End

It 'blocks Copilot bash input with string toolArgs'
Data '{"toolName": "bash", "toolArgs": "{\"command\":\"rm -rf /*\"}"}'
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
