#!/usr/bin/env bash
# shellcheck disable=SC2286,SC2288

Describe 'config/shared/hooks/block-git-identity.sh'
SCRIPT="$PWD/config/shared/hooks/block-git-identity.sh"

run_hook() {
  jq -n --arg command "$1" '{tool_input: {command: $command}}' | bash "$SCRIPT"
}

Describe 'blocks identity writes'
Parameters
'LEFTHOOK=0 git config user.name "openhands"; git commit -m x'
'git config user.email openhands@all-hands.dev'
'git -C /tmp/repo config --global user.email a@b.c'
'git config --local User.Name bot'
'git config --unset user.name'
'git config --unset-all user.email'
'git config --replace-all user.name bot'
'git config set user.email a@b.c'
'git config unset --global user.name'
'git config --remove-section user'
'/usr/bin/git config --worktree user.name bot'
'sh -c "git config user.name bot"'
'git status && git config user.email a@b.c'
End

It "blocks: $1"
When call run_hook "$1"
The status should equal 2
The stderr should include 'BLOCKED by block-git-identity.sh'
End
End

Describe 'allows reads and unrelated config'
Parameters
'git config user.email'
'git config --get user.name'
'git config get user.email'
'git config --list --show-origin'
'git -c user.name=x -c user.email=y commit -m z'
'git config core.hooksPath .githooks'
'git commit -m "set user.name in docs"'
'echo git config user.name'
''
End

It "allows: $1"
When call run_hook "$1"
The status should be success
End
End
End
