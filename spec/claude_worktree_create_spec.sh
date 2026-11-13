#!/usr/bin/env bash
# shellcheck disable=SC2329,SC2016

Describe 'claude worktree-create.sh'
SCRIPT="$PWD/config/claude/hooks/worktree-create.sh"
DEFAULT_NIX="$PWD/config/claude/default.nix"
SETTINGS="$PWD/config/claude/settings.json"
TEMPLATE="$PWD/config/claude/settings.tpl.json"

setup() {
  REPO="$(mktemp -d)"
  REPO="$(cd "$REPO" && pwd -P)"
  git -C "$REPO" init -q -b main
  git -C "$REPO" -c user.name=t -c user.email=t@t commit -q --allow-empty -m init
}
cleanup() {
  rm -rf "$REPO"
}
Before 'setup'
After 'cleanup'

Describe 'wiring'
It 'declares the hook in the user settings tier'
When run jq -r '.hooks.WorktreeCreate[0].hooks[0].command' "$SETTINGS"
The output should eq '$HOME/.claude/hooks/worktree-create.sh'
End

It 'keeps the template in sync'
When run jq -r '.hooks.WorktreeCreate[0].hooks[0].command' "$TEMPLATE"
The output should eq '$HOME/.claude/hooks/worktree-create.sh'
End

It 'installs the hook script'
When run cat "$DEFAULT_NIX"
The output should include 'home.file.".claude/hooks/worktree-create.sh"'
End
End

Describe 'repo without its own worktree script'
It 'creates the default worktree and prints only its path'
When run bash -c 'printf "{\"cwd\":\"%s\",\"name\":\"demo\"}" "$1" | bash "$2"' _ "$REPO" "$SCRIPT"
The status should be success
The output should eq "$REPO/.claude/worktrees/demo"
The path "$REPO/.claude/worktrees/demo/.git" should be exist
End

It 'resolves the canonical checkout from inside a worktree'
run_from_worktree() {
  git -C "$REPO" worktree add -q -b other "$REPO/.claude/worktrees/other" HEAD
  printf '{"cwd":"%s","name":"nested"}' "$REPO/.claude/worktrees/other" | bash "$SCRIPT"
}
When call run_from_worktree
The status should be success
The output should eq "$REPO/.claude/worktrees/nested"
End

It 'rejects input without a name'
When run bash -c 'printf "{\"cwd\":\"%s\"}" "$1" | bash "$2"' _ "$REPO" "$SCRIPT"
The status should eq 2
The stderr should include 'no name'
End
End

Describe 'repo that ships scripts/claude-worktree.ts'
It 'delegates to the repo script with the hook input on stdin'
delegate() {
  mkdir -p "$REPO/scripts" "$REPO/bin"
  : >"$REPO/scripts/claude-worktree.ts"
  printf '#!/usr/bin/env bash\necho "args=$*"\necho "stdin=$(cat)"\n' >"$REPO/bin/bun"
  chmod +x "$REPO/bin/bun"
  printf '{"cwd":"%s","name":"demo"}' "$REPO" | PATH="$REPO/bin:$PATH" bash "$SCRIPT"
}
When call delegate
The status should be success
The line 1 of output should eq "args=--no-install $REPO/scripts/claude-worktree.ts"
The line 2 of output should eq "stdin={\"cwd\":\"$REPO\",\"name\":\"demo\"}"
End
End
End
