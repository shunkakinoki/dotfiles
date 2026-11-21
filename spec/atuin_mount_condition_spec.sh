#!/usr/bin/env bash
# shellcheck disable=SC2329

# Run against the host mount namespace, which Nix build sandboxes do not expose.
Describe 'Atuin systemd mount condition'
no_systemd_analyze() { ! command -v systemd-analyze >/dev/null 2>&1; }
Skip if 'systemd-analyze is unavailable' no_systemd_analyze

setup() { MOUNT_TEST_DIR=$(mktemp -d); }
cleanup() { rm -rf "$MOUNT_TEST_DIR"; }
Before 'setup'
After 'cleanup'

It 'rejects an ordinary directory without starting services'
When run systemd-analyze condition "ConditionPathIsMountPoint=$MOUNT_TEST_DIR"
The status should be failure
The stderr should include 'ConditionPathIsMountPoint'
End

It 'accepts the root mount without starting services'
When run systemd-analyze condition 'ConditionPathIsMountPoint=/'
The status should be success
The stderr should include 'ConditionPathIsMountPoint'
End
End
