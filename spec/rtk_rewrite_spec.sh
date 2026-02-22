#!/usr/bin/env bash
# shellcheck disable=SC2329

Describe 'rtk-rewrite.sh'
SCRIPT="$PWD/config/claude/rtk-rewrite.sh"

# Create a mock rtk binary so the guard passes in CI where rtk is not installed
MOCK_BIN="$SHELLSPEC_TMPBASE/mock_bin"
mkdir -p "$MOCK_BIN"
printf '#!/bin/bash\nexit 0\n' > "$MOCK_BIN/rtk"
chmod +x "$MOCK_BIN/rtk"

run_hook() {
  PATH="$MOCK_BIN:$PATH" bash "$SCRIPT"
}

run_hook_jq() {
  PATH="$MOCK_BIN:$PATH" bash "$SCRIPT" | jq -r '.hookSpecificOutput.updatedInput.command'
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
It 'skips commands already using rtk'
Data '{"tool_input": {"command": "rtk git status"}}'
When run run_hook
The status should be success
The output should eq ''
End

It 'skips heredoc commands'
Data '{"tool_input": {"command": "cat <<EOF\nhello\nEOF"}}'
When run run_hook
The status should be success
The output should eq ''
End
End

Describe 'git rewrites'
It 'rewrites git status'
Data '{"tool_input": {"command": "git status"}}'
When run run_hook_jq
The status should be success
The output should eq 'rtk git status'
End

It 'rewrites git diff'
Data '{"tool_input": {"command": "git diff"}}'
When run run_hook_jq
The status should be success
The output should eq 'rtk git diff'
End

It 'rewrites git log with options'
Data '{"tool_input": {"command": "git log --oneline -5"}}'
When run run_hook_jq
The status should be success
The output should eq 'rtk git log --oneline -5'
End

It 'does not rewrite git clone'
Data '{"tool_input": {"command": "git clone https://example.com/repo"}}'
When run run_hook
The status should be success
The output should eq ''
End
End

Describe 'gh rewrites'
It 'rewrites gh pr list'
Data '{"tool_input": {"command": "gh pr list"}}'
When run run_hook_jq
The status should be success
The output should eq 'rtk gh pr list'
End

It 'does not rewrite gh auth'
Data '{"tool_input": {"command": "gh auth status"}}'
When run run_hook
The status should be success
The output should eq ''
End
End

Describe 'cargo rewrites'
It 'rewrites cargo test'
Data '{"tool_input": {"command": "cargo test"}}'
When run run_hook_jq
The status should be success
The output should eq 'rtk cargo test'
End

It 'rewrites cargo build'
Data '{"tool_input": {"command": "cargo build"}}'
When run run_hook_jq
The status should be success
The output should eq 'rtk cargo build'
End

It 'does not rewrite cargo new'
Data '{"tool_input": {"command": "cargo new myproject"}}'
When run run_hook
The status should be success
The output should eq ''
End
End

Describe 'file operation rewrites'
It 'rewrites cat to rtk read'
Data '{"tool_input": {"command": "cat file.txt"}}'
When run run_hook_jq
The status should be success
The output should eq 'rtk read file.txt'
End

It 'rewrites ls'
Data '{"tool_input": {"command": "ls -la"}}'
When run run_hook_jq
The status should be success
The output should eq 'rtk ls -la'
End

It 'rewrites find'
Data '{"tool_input": {"command": "find . -name \"*.ts\""}}'
When run run_hook_jq
The status should be success
The output should include 'rtk find'
End
End

Describe 'JS/TS tooling rewrites'
It 'rewrites vitest'
Data '{"tool_input": {"command": "vitest run"}}'
When run run_hook_jq
The status should be success
The output should eq 'rtk vitest run'
End

It 'rewrites pnpm test'
Data '{"tool_input": {"command": "pnpm test"}}'
When run run_hook_jq
The status should be success
The output should eq 'rtk vitest run'
End

It 'rewrites npm test'
Data '{"tool_input": {"command": "npm test"}}'
When run run_hook_jq
The status should be success
The output should eq 'rtk npm test'
End
End

Describe 'network rewrites'
It 'rewrites curl'
Data '{"tool_input": {"command": "curl https://example.com"}}'
When run run_hook_jq
The status should be success
The output should include 'rtk curl'
End
End

Describe 'python rewrites'
It 'rewrites pytest'
Data '{"tool_input": {"command": "pytest tests/"}}'
When run run_hook_jq
The status should be success
The output should include 'rtk pytest'
End
End

Describe 'go rewrites'
It 'rewrites go test'
Data '{"tool_input": {"command": "go test ./..."}}'
When run run_hook_jq
The status should be success
The output should include 'rtk go test'
End
End

Describe 'env prefix preservation'
It 'preserves env vars in rewritten command'
Data '{"tool_input": {"command": "FOO=bar git status"}}'
When run run_hook_jq
The status should be success
The output should include 'FOO=bar rtk git status'
End
End

Describe 'output format'
It 'outputs valid JSON with permissionDecision'
Data '{"tool_input": {"command": "git status"}}'
When run run_hook
The status should be success
The output should include '"permissionDecision"'
The output should include '"allow"'
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
