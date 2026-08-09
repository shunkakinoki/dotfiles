#!/usr/bin/env bash
# shellcheck disable=SC2329

Describe 'kyber/activate-build-toolchain.sh'
SCRIPT="$PWD/named-hosts/kyber/activate-build-toolchain.sh"
UNIT="$PWD/named-hosts/kyber/default.nix"

Describe 'script properties'
It 'uses strict mode (set -euo pipefail)'
When run bash -c "head -20 '$SCRIPT'"
The output should include 'set -euo pipefail'
End

# Nix cannot supply this: every nix compiler targets the nix glibc, which is the
# cause rather than the cure. Keep the reasoning next to the code.
It 'documents why a nix compiler cannot be used'
When run bash -c "cat '$SCRIPT'"
The output should include 'GLIBC'
The output should include 'nix glibc'
End
End

Describe 'idempotence'
setup() {
  mock_bin_setup apt-get sudo
  FAKE_BIN="$(mktemp -d)"
}

cleanup() {
  mock_bin_cleanup
  rm -rf "$FAKE_BIN"
}

Before 'setup'
After 'cleanup'

# /usr/bin/g++ exists on the CI runner and on kyber post-install, so the script
# must short-circuit rather than re-running apt on every activation.
It 'exits early and installs nothing when g++ is present'
Skip if 'g++ not installed' test ! -x /usr/bin/g++
When run bash -c "bash '$SCRIPT'; cat '$MOCK_LOG'"
The output should not include 'apt-get'
The status should be success
End

It 'checks for g++ before doing any work'
When run bash -c "grep -n 'x /usr/bin/g++' '$SCRIPT' | head -1"
The output should include '/usr/bin/g++'
End
End

Describe 'privilege escalation'
It 'falls back across sudo and doas like the sibling activation scripts'
When run bash -c "cat '$SCRIPT'"
The output should include 'SUDO_CMD'
The output should include 'doas'
End

It 'fails when root is required but unavailable'
When run bash -c "grep -A2 'sudo/doas is not available' '$SCRIPT'"
The output should include 'exit 1'
End
End

Describe 'installation'
It 'installs build-essential rather than g++ alone'
When run bash -c "grep 'apt-get install' '$SCRIPT'"
The output should include 'build-essential'
End

It 'verifies g++ exists afterwards and fails loudly otherwise'
When run bash -c "grep -A3 'still missing' '$SCRIPT'"
The output should include 'exit 1'
End
End

Describe 'nix wiring'
It 'is invoked from the kyber home-manager activation'
When run bash -c "cat '$UNIT'"
The output should include 'activate-build-toolchain.sh'
End

# npm globals builds node-pty, so the compiler has to be present first.
It 'runs before the npm globals install'
When run bash -c "cat '$UNIT'"
The output should include 'entryBefore [ "installNpmGlobals" ]'
End
End

End
