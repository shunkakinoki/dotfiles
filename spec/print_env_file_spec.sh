#!/usr/bin/env bash
# shellcheck disable=SC2329,SC2016

Describe 'home-manager/modules/dotenv/print-env-file.sh'
SCRIPT="$PWD/home-manager/modules/dotenv/print-env-file.sh"

setup() {
  TEST_HOME="$(mktemp -d)"
  export TEST_HOME
}
cleanup() {
  rm -rf "$TEST_HOME"
  unset TEST_HOME
}
Before 'setup'
After 'cleanup'

print_env() {
  printf '%s\n' "$1" >"$TEST_HOME/env"
  DOTFILES_ENV_FILE="$TEST_HOME/env" HOME="$TEST_HOME" sh "$SCRIPT"
}

Describe 'script properties'
It 'uses sh shebang'
When run bash -c "head -1 '$SCRIPT'"
The output should include '#!/usr/bin/env sh'
End

It 'passes sh syntax check'
When run bash -c "sh -n '$SCRIPT'"
The status should be success
End
End

Describe 'parsing'
It 'prints a plain assignment'
When call print_env 'AMP_API_KEY=amp-value'
The output should equal 'AMP_API_KEY=amp-value'
End

It 'strips double quotes'
When call print_env 'OPENCODE_API_KEY="sk-quoted"'
The output should equal 'OPENCODE_API_KEY=sk-quoted'
End

It 'strips single quotes'
When call print_env "OPENCODE_API_KEY='sk-single'"
The output should equal 'OPENCODE_API_KEY=sk-single'
End

It 'strips an export prefix'
When call print_env 'export AMP_API_KEY=exported'
The output should equal 'AMP_API_KEY=exported'
End

It 'keeps values containing spaces'
When call print_env 'AMP_API_KEY="two words"'
The output should equal 'AMP_API_KEY=two words'
End

It 'keeps equals signs inside the value'
When call print_env 'AMP_API_KEY=a=b'
The output should equal 'AMP_API_KEY=a=b'
End

It 'trims surrounding whitespace'
When call print_env '  AMP_API_KEY = spaced  '
The output should equal 'AMP_API_KEY=spaced'
End

It 'skips comments'
When call print_env '# AMP_API_KEY=commented'
The output should equal ''
End

It 'skips lines without an assignment'
When call print_env 'not-an-assignment'
The output should equal ''
End

It 'skips keys that are not identifiers'
When call print_env 'AMP-API-KEY=dashed'
The output should equal ''
End

It 'prints every valid line'
When call print_env 'AMP_API_KEY=amp
# comment
OPENCODE_API_KEY=opencode'
The line 1 of output should equal 'AMP_API_KEY=amp'
The line 2 of output should equal 'OPENCODE_API_KEY=opencode'
End
End

Describe 'candidate resolution'
It 'falls back to $HOME/dotfiles/.env'
When run bash -c "mkdir -p '$TEST_HOME/dotfiles' && printf 'AMP_API_KEY=from-dotfiles\n' >'$TEST_HOME/dotfiles/.env' && HOME='$TEST_HOME' sh '$SCRIPT'"
The output should equal 'AMP_API_KEY=from-dotfiles'
End

It 'falls back to $HOME/.env'
When run bash -c "printf 'AMP_API_KEY=from-home\n' >'$TEST_HOME/.env' && HOME='$TEST_HOME' sh '$SCRIPT'"
The output should equal 'AMP_API_KEY=from-home'
End

It 'succeeds when no env file exists'
When run bash -c "HOME='$TEST_HOME' sh '$SCRIPT'"
The status should be success
The output should equal ''
End
End
End
