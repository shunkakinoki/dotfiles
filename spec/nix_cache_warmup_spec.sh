#!/usr/bin/env bash
# shellcheck disable=SC2329,SC2034,SC2016

Describe 'scripts/nix-cache-warmup.sh'
SCRIPT="$PWD/scripts/nix-cache-warmup.sh"

Describe 'script properties'
It 'uses sh shebang'
When run bash -c "head -1 '$SCRIPT'"
The output should include '#!/bin/sh'
End

It 'uses strict mode'
When run bash -c "head -5 '$SCRIPT'"
The output should include 'set -e'
End
End

Describe 'github token handling'
It 'checks GITHUB_TOKEN env var'
When run bash -c "grep 'GITHUB_TOKEN' '$SCRIPT'"
The output should include 'GITHUB_TOKEN'
End

It 'checks GITHUB_TOKEN_FILE env var'
When run bash -c "grep 'GITHUB_TOKEN_FILE' '$SCRIPT'"
The output should include 'GITHUB_TOKEN_FILE'
End

It 'sets access-tokens in NIX_CONFIG'
When run bash -c "grep 'access-tokens' '$SCRIPT'"
The output should include 'access-tokens'
End

It 'unsets token variable after use'
When run bash -c "grep 'unset nix_github_token' '$SCRIPT'"
The output should include 'unset nix_github_token'
End
End

Describe 'nix availability check'
It 'checks if nix command exists'
When run bash -c "grep 'command -v nix' '$SCRIPT'"
The output should include 'command -v nix'
End

It 'skips gracefully when nix is unavailable'
When run bash -c "grep 'skipping cache warmup' '$SCRIPT'"
The output should include 'skipping cache warmup'
End
End

Describe 'flake metadata'
It 'runs nix flake metadata'
When run bash -c "grep 'nix flake metadata' '$SCRIPT'"
The output should include 'nix flake metadata'
End

It 'uses --no-write-lock-file flag'
When run bash -c "grep 'no-write-lock-file' '$SCRIPT'"
The output should include '--no-write-lock-file'
End
End

Describe 'repo directory argument'
It 'defaults repo_dir to current directory'
When run bash -c "grep 'repo_dir=\${1:-.}' '$SCRIPT'"
The output should include 'repo_dir=${1:-.}'
End
End

End
