#!/usr/bin/env bash
# shellcheck disable=SC2329

Describe 'home-manager/services/openclaw/gateway-tmp-cleanup.sh'
SCRIPT="$PWD/home-manager/services/openclaw/gateway-tmp-cleanup.sh"

setup() {
  TEMP_DIR=$(mktemp -d)
  mkdir -p \
    "$TEMP_DIR/tmp/openclaw-plugin-build-abc123/nested" \
    "$TEMP_DIR/tmp/openclaw-model-catalog-def456/openclaw-plugin-build-ghi789" \
    "$TEMP_DIR/tmp/openclaw-other-dir"
  touch "$TEMP_DIR/tmp/openclaw-plugin-build-abc123/nested/chunk.mjs" \
    "$TEMP_DIR/tmp/openclaw-plugin-build-file" \
    "$TEMP_DIR/tmp/openclaw-gateway.log"
}
cleanup() { rm -rf "$TEMP_DIR"; }
BeforeEach 'setup'
AfterEach 'cleanup'

It 'passes bash syntax check'
When run bash -n "$SCRIPT"
The status should be success
End

It 'removes leaked plugin-build and model-catalog directories'
When run env TMPDIR="$TEMP_DIR/tmp" bash -c "bash '$SCRIPT' && ls -1 '$TEMP_DIR/tmp'"
The status should be success
The output should not include 'openclaw-plugin-build-abc123'
The output should not include 'openclaw-model-catalog-def456'
The output should include 'openclaw-other-dir'
The output should include 'openclaw-plugin-build-file'
The output should include 'openclaw-gateway.log'
End

It 'creates a missing TMPDIR'
When run env TMPDIR="$TEMP_DIR/missing/openclaw-gateway" bash -c "bash '$SCRIPT' && test -d '$TEMP_DIR/missing/openclaw-gateway'"
The status should be success
End

It 'refuses to run without TMPDIR'
When run env -u TMPDIR bash "$SCRIPT"
The status should be failure
The error should include 'TMPDIR'
End
End
