#!/usr/bin/env bash
# shellcheck disable=SC2329

Describe 'auto-switch.sh'
SCRIPT="$PWD/config/claude/hooks/auto-switch.sh"

It 'exits 0 when cswap is not available'
  # Mock command so cswap is not found
  command() { return 1; }
  When run bash -c "command() { return 1; }; source '$SCRIPT' </dev/null"
  The status should equal 0
End

End
