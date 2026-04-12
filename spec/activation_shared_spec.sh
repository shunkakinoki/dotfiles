#!/usr/bin/env bash
# shellcheck disable=SC2329

Describe 'home-manager/activation/ensure-directory.sh'
SCRIPT="$PWD/home-manager/activation/ensure-directory.sh"

Describe 'script properties'
It 'uses bash shebang'
When run bash -c "head -1 '$SCRIPT'"
The output should include '#!/usr/bin/env bash'
End

It 'uses strict mode'
When run bash -c "head -5 '$SCRIPT'"
The output should include 'set -euo pipefail'
End
End

Describe 'directory creation'
It 'accepts mode as first argument'
When run bash -c "grep 'MODE=' '$SCRIPT'"
The output should include 'MODE="$1"'
End

It 'creates directories with mkdir -p'
When run bash -c "grep 'mkdir -p' '$SCRIPT'"
The output should include 'mkdir -p'
End

It 'sets permissions with chmod'
When run bash -c "grep 'chmod' '$SCRIPT'"
The output should include 'chmod'
End

It 'supports multiple directories'
When run bash -c "grep 'for DIR' '$SCRIPT'"
The output should include 'for DIR'
End
End
End

Describe 'home-manager/activation/deploy-agenix-secret.sh'
SCRIPT="$PWD/home-manager/activation/deploy-agenix-secret.sh"

Describe 'script properties'
It 'uses bash shebang'
When run bash -c "head -1 '$SCRIPT'"
The output should include '#!/usr/bin/env bash'
End

It 'uses strict mode'
When run bash -c "head -5 '$SCRIPT'"
The output should include 'set -euo pipefail'
End
End

Describe 'secret deployment'
It 'skips if destination already exists'
When run bash -c "grep 'exit 0' '$SCRIPT'"
The output should include 'exit 0'
End

It 'uses rage for decryption'
When run bash -c "grep 'RAGE_BIN' '$SCRIPT'"
The output should include 'RAGE_BIN'
End

It 'sets permissions to 0600'
When run bash -c "grep 'chmod 0600' '$SCRIPT'"
The output should include 'chmod 0600'
End

It 'warns when secret file not found'
When run bash -c "grep 'Secret file not found' '$SCRIPT'"
The output should include 'Secret file not found'
End
End
End

Describe 'home-manager/activation/import-gpg-key.sh'
SCRIPT="$PWD/home-manager/activation/import-gpg-key.sh"

Describe 'script properties'
It 'uses bash shebang'
When run bash -c "head -1 '$SCRIPT'"
The output should include '#!/usr/bin/env bash'
End

It 'uses strict mode'
When run bash -c "head -5 '$SCRIPT'"
The output should include 'set -euo pipefail'
End
End

Describe 'GPG key import'
It 'checks if key is already imported'
When run bash -c "grep 'list-secret-keys' '$SCRIPT'"
The output should include 'list-secret-keys'
End

It 'uses rage for decryption'
When run bash -c "grep 'RAGE_BIN' '$SCRIPT'"
The output should include 'RAGE_BIN'
End

It 'imports with gpg --batch --import'
When run bash -c "grep 'batch --import' '$SCRIPT'"
The output should include 'batch --import'
End

It 'cleans up temp file after import'
When run bash -c "grep 'rm -f' '$SCRIPT'"
The output should include 'rm -f'
End

It 'accepts key fingerprint as argument'
When run bash -c "grep 'KEY_FINGERPRINT' '$SCRIPT'"
The output should include 'KEY_FINGERPRINT'
End
End
End
