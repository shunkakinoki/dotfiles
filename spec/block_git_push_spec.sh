#!/usr/bin/env bash
# shellcheck disable=SC2329

Describe 'block-git-push.sh'
SCRIPT="$PWD/config/shared/hooks/block-git-push.sh"

setup() {
  TEMP_REPO=$(mktemp -d)
  git -C "$TEMP_REPO" init -q
  git -C "$TEMP_REPO" remote add origin "https://github.com/someorg/somerepo.git"
}

setup_allowed() {
  TEMP_REPO=$(mktemp -d)
  git -C "$TEMP_REPO" init -q
  git -C "$TEMP_REPO" remote add origin "https://github.com/shunkakinoki/wiki.git"
}

cleanup() {
  rm -rf "$TEMP_REPO"
}

After 'cleanup'

Describe 'non-push commands'
Before 'setup'

It 'allows git status'
Data '{"tool_input": {"command": "git status"}}'
When run bash -c "cd '$TEMP_REPO' && bash '$SCRIPT'"
The status should be success
End

It 'allows git pull'
Data '{"tool_input": {"command": "git pull origin main"}}'
When run bash -c "cd '$TEMP_REPO' && bash '$SCRIPT'"
The status should be success
End

It 'allows git push to feature branch'
Data '{"tool_input": {"command": "git push origin feat/my-branch"}}'
When run bash -c "cd '$TEMP_REPO' && bash '$SCRIPT'"
The status should be success
End
End

Describe 'blocked pushes'
Before 'setup'

It 'blocks git push origin main'
Data '{"tool_input": {"command": "git push origin main"}}'
When run bash -c "cd '$TEMP_REPO' && bash '$SCRIPT'"
The status should eq 2
The stderr should include 'BLOCKED'
End

It 'blocks git push origin master'
Data '{"tool_input": {"command": "git push origin master"}}'
When run bash -c "cd '$TEMP_REPO' && bash '$SCRIPT'"
The status should eq 2
The stderr should include 'BLOCKED'
End

It 'blocks git push -u origin main'
Data '{"tool_input": {"command": "git push -u origin main"}}'
When run bash -c "cd '$TEMP_REPO' && bash '$SCRIPT'"
The status should eq 2
The stderr should include 'BLOCKED'
End

It 'blocks git push --force origin main'
Data '{"tool_input": {"command": "git push --force origin main"}}'
When run bash -c "cd '$TEMP_REPO' && bash '$SCRIPT'"
The status should eq 2
The stderr should include 'BLOCKED'
End
End

Describe 'allowed repos'
Before 'setup_allowed'

It 'allows push to main in shunkakinoki/wiki'
Data '{"tool_input": {"command": "git push origin main"}}'
When run bash -c "cd '$TEMP_REPO' && bash '$SCRIPT'"
The status should be success
End

It 'allows push to master in shunkakinoki/wiki'
Data '{"tool_input": {"command": "git push origin master"}}'
When run bash -c "cd '$TEMP_REPO' && bash '$SCRIPT'"
The status should be success
End
End

Describe 'codex input format'
Before 'setup'

It 'blocks codex-style input with .command key'
Data '{"command": "git push origin main"}'
When run bash -c "cd '$TEMP_REPO' && bash '$SCRIPT'"
The status should eq 2
The stderr should include 'BLOCKED'
End
End

Describe 'edge cases'
Before 'setup'

It 'passes with empty input'
Data '{}'
When run bash -c "cd '$TEMP_REPO' && bash '$SCRIPT'"
The status should be success
End

It 'passes with empty command'
Data '{"tool_input": {"command": ""}}'
When run bash -c "cd '$TEMP_REPO' && bash '$SCRIPT'"
The status should be success
End
End
End
