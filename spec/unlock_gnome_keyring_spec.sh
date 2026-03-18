#!/usr/bin/env bash
# shellcheck disable=SC2329

Describe 'named-hosts/matic/unlock-gnome-keyring.py'
SCRIPT="$PWD/named-hosts/matic/unlock-gnome-keyring.py"

Describe 'script properties'
It 'has python3 placeholder shebang'
When run bash -c "head -1 '$SCRIPT'"
The output should include '@python3@/bin/python3'
End

It 'passes Python syntax check after stripping shebang'
When run bash -c "tail -n +2 '$SCRIPT' | python3 -c 'import sys; compile(sys.stdin.read(), \"<string>\", \"exec\")'"
The status should be success
End
End

Describe 'protocol implementation'
It 'uses UNIX socket'
When run bash -c "grep 'AF_UNIX' '$SCRIPT'"
The output should include 'AF_UNIX'
End

It 'uses XDG_RUNTIME_DIR'
When run bash -c "grep 'XDG_RUNTIME_DIR' '$SCRIPT'"
The output should include 'XDG_RUNTIME_DIR'
End

It 'reads from stdin'
When run bash -c "grep 'stdin.read' '$SCRIPT'"
The output should include 'stdin.read'
End

It 'validates socket ownership'
When run bash -c "grep 'st.st_uid' '$SCRIPT'"
The output should include 'st.st_uid'
End
End

Describe 'result codes'
It 'handles OK result'
When run bash -c "grep '\"OK\"' '$SCRIPT'"
The output should include 'OK'
End

It 'handles DENIED result'
When run bash -c "grep 'DENIED' '$SCRIPT'"
The output should include 'DENIED'
End

It 'exits non-zero on failure'
When run bash -c "grep 'sys.exit' '$SCRIPT'"
The output should include 'sys.exit'
End
End

End
