#!/usr/bin/env bash
# shellcheck disable=SC2329

Describe 'yek/install-yek.sh'
SCRIPT="$PWD/home-manager/modules/yek/install-yek.sh"

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

Describe 'configuration'
It 'uses bodo-run as repo owner'
When run bash -c "grep 'REPO_OWNER=' '$SCRIPT'"
The output should include 'bodo-run'
End

It 'uses yek as repo name'
When run bash -c "grep 'REPO_NAME=' '$SCRIPT'"
The output should include 'yek'
End

It 'installs to ~/.local/bin'
When run bash -c "grep 'INSTALL_DIR=' '$SCRIPT'"
The output should include '.local/bin'
End
End

Describe 'download process'
It 'fetches release info from GitHub API'
When run bash -c "grep '@curl@' '$SCRIPT' | head -1"
The output should include 'api.github.com'
End

It 'looks for browser_download_url'
When run bash -c "grep '@grep@' '$SCRIPT' | head -1"
The output should include 'browser_download_url'
End

It 'fails if no release asset found'
When run bash -c "grep 'exit 1' '$SCRIPT'"
The output should include 'exit 1'
End
End

Describe 'installation'
It 'creates temp directory for download'
When run bash -c "grep '@mktemp@' '$SCRIPT'"
The output should include '-d'
End

It 'extracts tar archive'
When run bash -c "grep '@tar@' '$SCRIPT'"
The output should include 'xzf'
End

It 'installs binary with correct permissions'
When run bash -c "grep '@install@' '$SCRIPT'"
The output should include '-Dm755'
End

It 'cleans up temp directory'
When run bash -c "grep 'rm -rf' '$SCRIPT'"
The output should include 'TEMP_DIR'
End
End

End

Describe 'yek/yek.sh'
WRAPPER_SCRIPT="$PWD/home-manager/modules/yek/yek.sh"

Describe 'script properties'
It 'uses bash shebang'
When run bash -c "head -1 '$WRAPPER_SCRIPT'"
The output should include '#!/usr/bin/env bash'
End

It 'uses strict mode'
When run bash -c "head -5 '$WRAPPER_SCRIPT'"
The output should include 'set -euo pipefail'
End
End

Describe 'configuration'
It 'uses ~/.local/bin for binary location'
When run bash -c "grep 'INSTALL_DIR=' '$WRAPPER_SCRIPT'"
The output should include '.local/bin'
End

It 'points to yek binary'
When run bash -c "grep 'YEK_BIN=' '$WRAPPER_SCRIPT'"
The output should include 'yek'
End
End

Describe 'auto-install behavior'
It 'checks if yek binary exists'
When run bash -c "grep '\[ ! -f' '$WRAPPER_SCRIPT'"
The output should include 'YEK_BIN'
End

It 'calls install-yek if binary missing'
When run bash -c "grep '@install_yek@' '$WRAPPER_SCRIPT'"
The output should include '@install_yek@'
End
End

Describe 'execution'
It 'uses exec to replace shell process'
When run bash -c "grep 'exec' '$WRAPPER_SCRIPT'"
The output should include 'YEK_BIN'
End

It 'passes all arguments to yek'
When run bash -c "grep '\"\$@\"' '$WRAPPER_SCRIPT'"
The output should include '$@'
End
End

End
