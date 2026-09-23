#!/usr/bin/env bash
# shellcheck disable=SC2329

Describe 'named-hosts/matic/gnome-keyring-tpm-unlock.sh'
SCRIPT="$PWD/named-hosts/matic/gnome-keyring-tpm-unlock.sh"
CONFIG="$PWD/named-hosts/matic/default.nix"

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

It 'takes the target UID as the first argument'
When run bash -c "grep 'TARGET_UID=\"\\\$1\"' '$SCRIPT'"
The output should include 'TARGET_UID='
End

It 'skips system users below uid 1000'
When run bash -c "grep '1000' '$SCRIPT'"
The output should include '1000'
End

It 'retries unlock up to 8 times'
When run bash -c "grep '1 2 3 4 5 6 7 8' '$SCRIPT'"
The output should include '1 2 3 4 5 6 7 8'
End

It 'fails when every attempt is exhausted'
When run bash -c "tail -2 '$SCRIPT'"
The output should include 'exit 1'
End
End

Describe 'systemd wiring in named-hosts/matic/default.nix'
It 'watches the keyring control socket per UID'
When run bash -c "awk '/systemd.paths.\"gnome-keyring-tpm-unlock@\" = \\{/{in_unit=1} in_unit{print} in_unit && /^        \\};/{exit}' '$CONFIG'"
The output should include 'PathExists = "/run/user/%i/keyring/control";'
The output should include 'Unit = "gnome-keyring-tpm-unlock@%i.service";'
End

It 'runs the unlock script with the UID as a oneshot'
When run bash -c "awk '/systemd.services.\"gnome-keyring-tpm-unlock@\" = \\{/{in_unit=1} in_unit{print} in_unit && /^        \\};/{exit}' '$CONFIG'"
The output should include 'Type = "oneshot";'
The output should include '%i'
End

It 'instantiates the watch from user@.service'
When run bash -c "awk '/systemd.services.\"user@\" = \\{/{in_unit=1} in_unit{print} in_unit && /^        \\};/{exit}' '$CONFIG'"
The output should include 'overrideStrategy = "asDropin";'
The output should include 'gnome-keyring-tpm-unlock@%i.path'
End

It 'no longer unlocks from the PAM session stack'
When run bash -c "grep -c 'pam_exec' '$CONFIG' || true"
The output should equal '0'
End
End

End
