#!/usr/bin/env bash
# shellcheck disable=SC2329

Describe 'generate-hooks.sh'
SCRIPT="$PWD/scripts/generate-hooks.sh"

It 'exists and is executable'
The path "$SCRIPT" should be exist
The path "$SCRIPT" should be executable
End

It 'renders all native Traces adapters into generated'
When run bash -c "grep -F 'GENERATED_ROOT/traces' '$SCRIPT'"
The output should include 'openclaw'
The output should include 'hermes'
The status should be success
End

It 'delegates Moshi output to the existing updater'
When run bash -c "grep -F 'update-moshi-hooks.sh' '$SCRIPT'"
The output should include 'GENERATED_ROOT'
The status should be success
End

It 'requires the repository managed Moshi generator'
When run bash -c "grep -F 'moshi-hook is required' '$SCRIPT'"
The output should include 'moshi-hook is required'
The status should be success
End
End
