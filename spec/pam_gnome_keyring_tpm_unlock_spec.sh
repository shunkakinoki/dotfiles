#!/usr/bin/env bash
# shellcheck disable=SC2329

Describe 'named-hosts/matic/pam-gnome-keyring-tpm-unlock.sh'
SCRIPT="$PWD/named-hosts/matic/pam-gnome-keyring-tpm-unlock.sh"

Describe 'script properties'
It 'uses bash shebang'
When run bash -c "head -1 '$SCRIPT'"
The output should include '#!/usr/bin/env bash'
End

It 'passes bash syntax check after stripping placeholders'
When run bash -c "sed 's|@[a-z_]*@|true|g' '$SCRIPT' | bash -n"
The status should be success
End
End

Describe 'placeholder substitutions'
It 'references @logger@'
When run bash -c "grep '@logger@' '$SCRIPT'"
The output should include '@logger@'
End

It 'references @systemd_creds@'
When run bash -c "grep '@systemd_creds@' '$SCRIPT'"
The output should include '@systemd_creds@'
End

It 'references @id@'
When run bash -c "grep '@id@' '$SCRIPT'"
The output should include '@id@'
End

It 'references @sleep@'
When run bash -c "grep '@sleep@' '$SCRIPT'"
The output should include '@sleep@'
End

It 'references @env@'
When run bash -c "grep '@env@' '$SCRIPT'"
The output should include '@env@'
End

It 'references @runuser@'
When run bash -c "grep '@runuser@' '$SCRIPT'"
The output should include '@runuser@'
End

It 'references @unlock_py@'
When run bash -c "grep '@unlock_py@' '$SCRIPT'"
The output should include '@unlock_py@'
End
End

Describe 'logic'
It 'exits 0 if credential file absent'
When run bash -c "grep '|| exit 0' '$SCRIPT'"
The output should include '|| exit 0'
End

It 'checks PAM_USER is set'
When run bash -c "grep 'PAM_USER' '$SCRIPT'"
The output should include 'PAM_USER'
End

It 'skips system users below uid 1000'
When run bash -c "grep '1000' '$SCRIPT'"
The output should include '1000'
End

It 'runs unlock in background subshell'
When run bash -c "grep -c ') &' '$SCRIPT'"
The output should include '1'
End

It 'retries unlock up to 8 times'
When run bash -c "grep '1 2 3 4 5 6 7 8' '$SCRIPT'"
The output should include '1 2 3 4 5 6 7 8'
End
End

End
