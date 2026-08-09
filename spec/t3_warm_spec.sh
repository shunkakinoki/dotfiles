#!/usr/bin/env bash
# shellcheck disable=SC2329

Describe 't3-warm/warm.sh'
SCRIPT="$PWD/home-manager/services/t3-warm/warm.sh"

setup() {
  mock_bin_setup npx npm
  FAKE_HOME="$(mktemp -d)"
  export HOME="$FAKE_HOME"
}

cleanup() {
  mock_bin_cleanup
  rm -rf "$FAKE_HOME"
}

Before 'setup'
After 'cleanup'

Describe 'cache warming'
It 'warms the nightly tag by default'
When run bash -c "bash '$SCRIPT' >/dev/null 2>&1; cat '$MOCK_LOG'"
The output should include 'npx --yes t3@nightly --version'
The status should be success
End

It 'honors T3_WARM_TAG override'
When run bash -c "T3_WARM_TAG=latest bash '$SCRIPT' >/dev/null 2>&1; cat '$MOCK_LOG'"
The output should include 't3@latest'
The status should be success
End
End

Describe 'node-pty rebuild'
make_cache_dir() {
  mkdir -p "$HOME/.npm/_npx/abc123/node_modules/node-pty"
}

It 'rebuilds node-pty with a scoped ignore-scripts override'
When run bash -c "$(declare -f make_cache_dir); make_cache_dir; bash '$SCRIPT' >/dev/null 2>&1; cat '$MOCK_LOG'"
The output should include 'npm rebuild --ignore-scripts=false node-pty'
The status should be success
End

It 'skips rebuild when pty.node is already built'
When run bash -c "$(declare -f make_cache_dir); make_cache_dir; mkdir -p \"\$HOME/.npm/_npx/abc123/node_modules/node-pty/build/Release\"; touch \"\$HOME/.npm/_npx/abc123/node_modules/node-pty/build/Release/pty.node\"; bash '$SCRIPT' >/dev/null 2>&1; cat '$MOCK_LOG'"
The output should not include 'npm rebuild'
The status should be success
End

It 'succeeds when no npx cache dirs exist'
When run bash "$SCRIPT"
The status should be success
End
End

Describe 'script properties'
It 'uses strict mode (set -euo pipefail)'
When run bash -c "head -20 '$SCRIPT'"
The output should include 'set -euo pipefail'
End

It 'documents why the scoped override is needed'
When run bash -c "cat '$SCRIPT'"
The output should include 'per-package allowlist'
End
End

End
