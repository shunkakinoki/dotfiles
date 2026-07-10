#!/usr/bin/env bash
# shellcheck disable=SC2329

sync_with_failing_scanner() {
  script=$1
  fixture=$(mktemp -d)
  git_bin=$(command -v git)
  git_prefix=${git_bin%/bin/git}

  mkdir -p \
    "$fixture/coreutils/bin" \
    "$fixture/gitleaks/bin" \
    "$fixture/gh/bin" \
    "$fixture/util-linux/bin" \
    "$fixture/vault/.hooks"

  ln -s "$(command -v date)" "$fixture/coreutils/bin/date"
  printf '#!/bin/sh\nprintf "generated context rejected\\n" >&2\nexit 23\n' >"$fixture/gitleaks/bin/gitleaks"
  printf '#!/bin/sh\nexit 0\n' >"$fixture/util-linux/bin/flock"
  printf '#!/bin/sh\ngitleaks detect\n' >"$fixture/vault/.hooks/pre-commit"
  chmod +x \
    "$fixture/gitleaks/bin/gitleaks" \
    "$fixture/util-linux/bin/flock" \
    "$fixture/vault/.hooks/pre-commit"

  "$git_bin" -C "$fixture/vault" init -q
  "$git_bin" -C "$fixture/vault" config user.email test@example.com
  "$git_bin" -C "$fixture/vault" config user.name 'Wiki Sync Test'
  printf 'initial\n' >"$fixture/vault/context.md"
  "$git_bin" -C "$fixture/vault" add context.md
  "$git_bin" -C "$fixture/vault" -c commit.gpgsign=false commit -q -m initial
  "$git_bin" -C "$fixture/vault" branch -M main
  "$git_bin" -C "$fixture/vault" config core.hooksPath .hooks
  printf 'updated\n' >>"$fixture/vault/context.md"

  sed \
    -e "s|@coreutils@|$fixture/coreutils|g" \
    -e "s|@gh@|$fixture/gh|g" \
    -e "s|@git@|$git_prefix|g" \
    -e "s|@gitleaks@|$fixture/gitleaks|g" \
    -e "s|@utilLinux@|$fixture/util-linux|g" \
    -e "s|@vaultDir@|$fixture/vault|g" \
    "$script" >"$fixture/sync"
  chmod +x "$fixture/sync"

  PATH=/usr/bin:/bin "$fixture/sync"
  status=$?
  rm -rf "$fixture"
  return "$status"
}

Describe 'home-manager/services/obsidian/obsidian-git-trigger.sh'
SCRIPT="$PWD/home-manager/services/obsidian/obsidian-git-trigger.sh"

Describe 'script properties'
It 'uses bash shebang'
When run bash -c "head -1 '$SCRIPT'"
The output should include '#!/usr/bin/env bash'
End

It 'passes bash syntax check after replacing placeholders'
When run bash -c "sed -e 's|@coreutils@|/usr|g' -e 's|@gh@|/usr|g' -e 's|@git@|/usr|g' -e 's|@gitleaks@|/usr|g' -e 's|@utilLinux@|/usr|g' -e 's|@vaultDir@|/tmp/wiki|g' '$SCRIPT' | bash -n"
The status should be success
End
End

Describe 'placeholder references'
It 'references git via placeholder'
When run bash -c "grep '@git@' '$SCRIPT'"
The output should include '@git@'
End

It 'references the GitHub CLI via placeholder'
When run bash -c "grep '@gh@' '$SCRIPT'"
The output should include '@gh@'
End

It 'references gitleaks via placeholder'
When run bash -c "grep '@gitleaks@' '$SCRIPT'"
The output should include '@gitleaks@'
End

It 'references flock via placeholder'
When run bash -c "grep '@utilLinux@' '$SCRIPT'"
The output should include '@utilLinux@'
End
End

Describe 'Git synchronization'
It 'serializes overlapping timer runs'
When run bash -c "grep 'flock -n' '$SCRIPT'"
The output should include 'flock -n'
End

It 'preserves concurrent vault writes while rebasing'
When run bash -c "grep 'rebase --autostash origin/main' '$SCRIPT'"
The output should include 'rebase --autostash origin/main'
End

It 'disables interactive signing for unattended commits'
When run bash -c "grep 'commit.gpgsign=false' '$SCRIPT'"
The output should include 'commit.gpgsign=false'
End

It 'fails closed when the pre-commit scanner rejects generated context'
When call sync_with_failing_scanner "$SCRIPT"
The status should be failure
The stderr should include 'generated context rejected'
End

It 'fails when the vault is not a Git checkout'
When run bash -c "grep 'vault is not a Git checkout' '$SCRIPT'"
The output should include 'vault is not a Git checkout'
End
End

End
