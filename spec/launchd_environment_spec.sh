#!/usr/bin/env bash
# shellcheck disable=SC2329

Describe 'launchd agent environment'
# launchd reads EnvironmentVariables and silently ignores any other key, so an
# agent declaring `Environment` runs with launchd's bare default PATH.
launchd_environment_keys() {
  git ls-files '*.nix' | while IFS= read -r file; do
    awk -v file="$file" '
      /launchd\.agents/ { in_launchd = 1 }
      /systemd\.user/ { in_launchd = 0 }
      in_launchd && /^[[:space:]]+Environment = / { print file ":" NR }
    ' "$file"
  done
}

It 'declares agent environments with EnvironmentVariables'
When call launchd_environment_keys
The output should equal ''
End
End
