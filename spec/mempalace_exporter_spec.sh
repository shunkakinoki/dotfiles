#!/usr/bin/env bash
# shellcheck disable=SC2016

Describe 'home-manager/services/mempalace-exporter/export.sh'
SCRIPT="$PWD/home-manager/services/mempalace-exporter/export.sh"
MODULE="$PWD/home-manager/services/mempalace-exporter/default.nix"

It 'uses strict Bash mode'
When run bash -c "head -3 '$SCRIPT'"
The status should be success
The output should include 'set -euo pipefail'
End

It 'locates the installed Python package without parsing ls output'
When run grep -F 'find "$MEMPALACE_BIN/lib"' "$SCRIPT"
The status should be success
The output should include "-path '*/python*/site-packages' -print -quit"
End

It 'exits successfully when mempalace is not installed'
TEMP_HOME=$(mktemp -d)
When run env HOME="$TEMP_HOME" bash "$SCRIPT"
The status should be success
The output should include 'mempalace not installed, skipping'
rm -rf "$TEMP_HOME"
End

It 'declares both launchd and systemd schedules'
When run cat "$MODULE"
The status should be success
The output should include 'launchd.agents.mempalace-exporter'
The output should include 'systemd.user.timers.mempalace-exporter'
End
End
