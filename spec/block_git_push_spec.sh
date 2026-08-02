#!/usr/bin/env bash
# shellcheck disable=SC2016,SC2329

Describe 'block-git-push.sh'
SCRIPT="$PWD/config/shared/hooks/block-git-push.sh"

setup() {
  TEMP_REPO=$(mktemp -d)
  git -C "$TEMP_REPO" init -q -b main
  git -C "$TEMP_REPO" config commit.gpgSign false
  git -C "$TEMP_REPO" config user.email agent@example.com
  git -C "$TEMP_REPO" config user.name Agent
  git -C "$TEMP_REPO" commit --allow-empty -q -m init
  git -C "$TEMP_REPO" remote add origin "https://github.com/someorg/somerepo.git"
}

setup_allowed() {
  TEMP_REPO=$(mktemp -d)
  git -C "$TEMP_REPO" init -q -b main
  git -C "$TEMP_REPO" config commit.gpgSign false
  git -C "$TEMP_REPO" config user.email agent@example.com
  git -C "$TEMP_REPO" config user.name Agent
  git -C "$TEMP_REPO" commit --allow-empty -q -m init
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

It 'allows a feature branch whose final path component is main'
Data '{"tool_input": {"command": "git push origin feature/main"}}'
When run bash -c "cd '$TEMP_REPO' && bash '$SCRIPT'"
The status should be success
End

It 'allows a feature branch whose final path component is master'
Data '{"tool_input": {"command": "git push origin release/master"}}'
When run bash -c "cd '$TEMP_REPO' && bash '$SCRIPT'"
The status should be success
End

It 'allows pushing main to a feature destination'
Data '{"tool_input": {"command": "git push origin main:feat/snapshot"}}'
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

It 'blocks a bare push from main'
Data '{"tool_input": {"command": "git push"}}'
When run bash -c "cd '$TEMP_REPO' && bash '$SCRIPT'"
The status should eq 2
The stderr should include 'BLOCKED'
End

It 'blocks HEAD from main'
Data '{"tool_input": {"command": "git push origin HEAD"}}'
When run bash -c "cd '$TEMP_REPO' && bash '$SCRIPT'"
The status should eq 2
The stderr should include 'BLOCKED'
End

It 'blocks an explicit HEAD destination'
Data '{"tool_input": {"command": "git push origin +HEAD:refs/heads/main"}}'
When run bash -c "cd '$TEMP_REPO' && bash '$SCRIPT'"
The status should eq 2
The stderr should include 'BLOCKED'
End

It 'blocks deleting main'
Data '{"tool_input": {"command": "git push origin --delete main"}}'
When run bash -c "cd '$TEMP_REPO' && bash '$SCRIPT'"
The status should eq 2
The stderr should include 'BLOCKED'
End

It 'blocks a deletion refspec for main'
Data '{"tool_input": {"command": "git push origin :main"}}'
When run bash -c "cd '$TEMP_REPO' && bash '$SCRIPT'"
The status should eq 2
The stderr should include 'BLOCKED'
End

It 'blocks pushing all branches when main exists'
Data '{"tool_input": {"command": "git push origin --all"}}'
When run bash -c "cd '$TEMP_REPO' && bash '$SCRIPT'"
The status should eq 2
The stderr should include 'BLOCKED'
End

It 'blocks mirroring refs'
Data '{"tool_input": {"command": "git push --mirror origin"}}'
When run bash -c "cd '$TEMP_REPO' && bash '$SCRIPT'"
The status should eq 2
The stderr should include 'BLOCKED'
End

It 'blocks a feature source targeting main'
Data '{"tool_input": {"command": "git push origin feat/work:main"}}'
When run bash -c "cd '$TEMP_REPO' && bash '$SCRIPT'"
The status should eq 2
The stderr should include 'BLOCKED'
End
End

Describe 'implicit destinations'
Before 'setup'

It 'blocks an upstream configured to main'
git -C "$TEMP_REPO" switch -q -c feat/upstream
git -C "$TEMP_REPO" config branch.feat/upstream.remote origin
git -C "$TEMP_REPO" config branch.feat/upstream.merge refs/heads/main
git -C "$TEMP_REPO" config push.default upstream
Data '{"tool_input": {"command": "git push"}}'
When run bash -c "cd '$TEMP_REPO' && bash '$SCRIPT'"
The status should eq 2
The stderr should include 'BLOCKED'
End

It 'blocks a remote push refspec targeting main'
git -C "$TEMP_REPO" switch -q -c feat/refspec
git -C "$TEMP_REPO" config remote.origin.push HEAD:refs/heads/main
Data '{"tool_input": {"command": "git push origin"}}'
When run bash -c "cd '$TEMP_REPO' && bash '$SCRIPT'"
The status should eq 2
The stderr should include 'BLOCKED'
End

It 'blocks the locally cached remote default branch'
git -C "$TEMP_REPO" switch -q -c trunk
git -C "$TEMP_REPO" update-ref refs/remotes/origin/trunk HEAD
git -C "$TEMP_REPO" symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/trunk
Data '{"tool_input": {"command": "git push origin HEAD"}}'
When run bash -c "cd '$TEMP_REPO' && bash '$SCRIPT'"
The status should eq 2
The stderr should include 'BLOCKED'
End

It 'blocks push.default matching when a protected branch exists'
git -C "$TEMP_REPO" switch -q -c feat/matching
git -C "$TEMP_REPO" config push.default matching
Data '{"tool_input": {"command": "git push origin"}}'
When run bash -c "cd '$TEMP_REPO' && bash '$SCRIPT'"
The status should eq 2
The stderr should include 'BLOCKED'
End

It 'allows a bare push from a feature branch without an upstream'
git -C "$TEMP_REPO" switch -q -c feat/no-upstream
Data '{"tool_input": {"command": "git push"}}'
When run bash -c "cd '$TEMP_REPO' && bash '$SCRIPT'"
The status should be success
End

It 'allows a bare push from detached HEAD because Git will reject it'
git -C "$TEMP_REPO" checkout -q --detach
Data '{"tool_input": {"command": "git push"}}'
When run bash -c "cd '$TEMP_REPO' && bash '$SCRIPT'"
The status should be success
End
End

Describe 'git aliases'
Before 'setup'

It 'blocks a push alias targeting main'
git -C "$TEMP_REPO" config alias.pushy 'push --force-with-lease'
Data '{"tool_input": {"command": "git pushy origin main"}}'
When run bash -c "cd '$TEMP_REPO' && bash '$SCRIPT'"
The status should eq 2
The stderr should include 'BLOCKED'
End

It 'blocks a nested push alias'
git -C "$TEMP_REPO" config alias.pushy 'push --force-with-lease'
git -C "$TEMP_REPO" config alias.ship pushy
Data '{"tool_input": {"command": "git ship origin main"}}'
When run bash -c "cd '$TEMP_REPO' && bash '$SCRIPT'"
The status should eq 2
The stderr should include 'BLOCKED'
End

It 'blocks a shell alias containing a bare push'
git -C "$TEMP_REPO" config alias.put '!git commit --all && git push'
Data '{"tool_input": {"command": "git put"}}'
When run bash -c "cd '$TEMP_REPO' && bash '$SCRIPT'"
The status should eq 2
The stderr should include 'BLOCKED'
End

It 'blocks the publish shell alias when it expands the current main branch'
git -C "$TEMP_REPO" config alias.publish '!f() { git push --set-upstream "${1:-origin}" "$(git current-branch)"; }; f'
Data '{"tool_input": {"command": "git publish"}}'
When run bash -c "cd '$TEMP_REPO' && bash '$SCRIPT'"
The status should eq 2
The stderr should include 'BLOCKED'
End

It 'allows a push alias targeting a feature branch'
git -C "$TEMP_REPO" config alias.publish-feature 'push origin feat/publish'
Data '{"tool_input": {"command": "git publish-feature"}}'
When run bash -c "cd '$TEMP_REPO' && bash '$SCRIPT'"
The status should be success
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

It 'blocks nested Codex tool input'
Data '{"tool": {"input": {"command": "git push origin main"}}}'
When run bash -c "cd '$TEMP_REPO' && bash '$SCRIPT'"
The status should eq 2
The stderr should include 'BLOCKED'
End
End

Describe 'copilot input format'
Before 'setup'

It 'blocks Copilot shell push to main'
Data '{"toolName": "shell", "toolArgs": {"command": "git push origin main"}}'
When run bash -c "cd '$TEMP_REPO' && bash '$SCRIPT'"
The status should eq 2
The stderr should include 'BLOCKED'
End

It 'blocks camel-case tool input'
Data '{"toolInput": {"command": "git push origin main"}}'
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
