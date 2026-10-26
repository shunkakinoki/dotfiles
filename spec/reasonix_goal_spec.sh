#!/usr/bin/env bash
# shellcheck disable=SC2329,SC2016

Describe 'Reasonix goal autostart function'
FUNC="$PWD/home-manager/programs/fish/functions/_rxgoal_function.fish"
FISH_MODULE="$PWD/home-manager/programs/fish/default.nix"

It 'passes the fish syntax check'
When run fish -n "$FUNC"
The status should be success
End

It 'reads the worker port and token from the published state directory'
When run bash -c "grep -E 'set -l (port_file|token_file) ' '$FUNC'"
The status should be success
The output should include 'port_file'
The output should include 'token_file'
End

It 'exchanges the token query for the auth cookie the worker expects'
When run bash -c "grep -F 'status?token=' '$FUNC'"
The status should be success
The output should include 'status?token='
End

It 'arms the goal before kicking, because arming alone does not schedule a round'
check() {
  grep -c -F '"$base/goal"' "$FUNC"
  grep -c -F '"$base/submit"' "$FUNC"
}
When call check
The line 1 of output should equal '2'
The line 2 of output should equal '1'
End

It 'supports a clear path so an armed goal can be withdrawn'
When run bash -c "grep -F '\"goal\":\"\"' '$FUNC'"
The status should be success
The output should include '"goal":""'
End

It 'is registered in the fish module functions list'
When run bash -c "grep -c -F '_rxgoal_function' '$FISH_MODULE'"
The status should be success
The output should not equal '0'
End

It 'exposes the rxgoal abbreviation'
When run bash -c "grep -F 'rxgoal = ' '$FISH_MODULE'"
The status should be success
The output should include 'rxgoal = "_rxgoal_function"'
End
End
