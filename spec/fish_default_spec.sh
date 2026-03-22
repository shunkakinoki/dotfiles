#!/usr/bin/env bash
# shellcheck disable=SC2329

Describe 'home-manager/programs/fish/default.nix'
SCRIPT="$PWD/home-manager/programs/fish/default.nix"

Describe 'OMP fish shortcuts'
It 'defines ompc abbreviation'
When run grep -F 'ompc = "omp commit";' "$SCRIPT"
The status should be success
The output should include 'ompc = "omp commit";'
End

It 'defines ompcp abbreviation'
When run grep -F 'ompcp = "omp commit --push";' "$SCRIPT"
The status should be success
The output should include 'ompcp = "omp commit --push";'
End

It 'registers ompxe helper abbreviation'
When run grep -F 'ompxe = "_ompxe_function";' "$SCRIPT"
The status should be success
The output should include 'ompxe = "_ompxe_function";'
End

It 'registers ompxeh helper abbreviation'
When run grep -F 'ompxeh = "_ompxeh_function";' "$SCRIPT"
The status should be success
The output should include 'ompxeh = "_ompxeh_function";'
End
End

End
