#!/usr/bin/env bash
# shellcheck disable=SC2016,SC2329

Describe 'Makefile sudo resolution'

It 'prefers the NixOS setuid wrapper over a sudo found on PATH'
When run bash -c '
  wrapper_line=$(grep -n "if \[ -x /run/wrappers/bin/sudo \]" Makefile | cut -d: -f1)
  path_line=$(grep -n "elif command -v sudo" Makefile | cut -d: -f1)
  test -n "$wrapper_line" && test -n "$path_line" && test "$wrapper_line" -lt "$path_line"
'
The status should be success
End

End
