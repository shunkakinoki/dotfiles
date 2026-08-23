#!/usr/bin/env bash
# shellcheck disable=SC2329,SC2016

Describe 'home-manager/modules/dotenv/load-env-file.sh'
SCRIPT="$PWD/home-manager/modules/dotenv/load-env-file.sh"
PRINTER="$PWD/home-manager/modules/dotenv/print-env-file.sh"

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

load_with() {
  printf '%s\n' "$1" >"$TEST_HOME/env"
  DOTFILES_ENV_FILE="$TEST_HOME/env" HM_PRINT_ENV_FILE="$PRINTER" HOME="$TEST_HOME" \
    "$2" -c ". '$SCRIPT'; _hm_load_env_file; printf '%s' \"\${$3:-<unset>}\""
}

Describe 'script properties'
It 'declares the sh shellcheck dialect'
When run bash -c "head -1 '$SCRIPT'"
The output should include 'shellcheck shell=sh'
End

It 'passes sh syntax check'
When run bash -c "sh -n '$SCRIPT'"
The status should be success
End

It 'delegates parsing to print-env-file.sh'
When run bash -c "grep -c 'print-env-file.sh' '$SCRIPT'"
The output should not equal '0'
End
End

Describe 'applying printer output'
It 'exports a plain assignment'
When call load_with 'AMP_API_KEY=amp-value' bash AMP_API_KEY
The output should equal 'amp-value'
End

It 'exports a dequoted value'
When call load_with 'OPENCODE_API_KEY="sk-quoted"' bash OPENCODE_API_KEY
The output should equal 'sk-quoted'
End

It 'keeps values containing spaces'
When call load_with 'AMP_API_KEY="two words"' bash AMP_API_KEY
The output should equal 'two words'
End

It 'keeps equals signs inside the value'
When call load_with 'AMP_API_KEY=a=b' bash AMP_API_KEY
The output should equal 'a=b'
End

It 'skips comments'
When call load_with '# AMP_API_KEY=commented' bash AMP_API_KEY
The output should equal '<unset>'
End

It 'works under dash-style sh'
When call load_with 'AMP_API_KEY=posix' sh AMP_API_KEY
The output should equal 'posix'
End
End

Describe 'missing printer'
It 'succeeds when the printer is absent'
When run bash -c "HM_PRINT_ENV_FILE='$TEST_HOME/missing' bash -c \". '$SCRIPT'; _hm_load_env_file\""
The status should be success
End

It 'leaves no helper variables behind'
When run bash -c "HM_PRINT_ENV_FILE='$PRINTER' HOME='$TEST_HOME' bash -c \". '$SCRIPT'; _hm_load_env_file; printf '%s' \\\"\\\${_hm_printer-<unset>}\\\"\""
The output should equal '<unset>'
End
End
End
