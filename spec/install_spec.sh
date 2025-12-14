#!/usr/bin/env bash
# shellcheck disable=SC2329

Describe 'install.sh'
SCRIPT="$PWD/install.sh"

Describe 'script structure'
It 'uses sh shebang for portability'
When run bash -c "head -1 '$SCRIPT'"
The output should include '#!/bin/sh'
End

It 'exits on error (set -e)'
When run bash -c "head -10 '$SCRIPT'"
The output should include 'set -e'
End
End

Describe 'OS detection logic'
It 'detects Darwin as macos'
When run bash -c "grep -A 3 'Darwin)' '$SCRIPT'"
The output should include 'OS="macos"'
End

It 'detects Linux as linux'
When run bash -c "grep -A 3 'Linux)' '$SCRIPT'"
The output should include 'OS="linux"'
End

It 'exits for unsupported OS'
When run bash -c "grep -A 2 'Unsupported operating system' '$SCRIPT'"
The output should include 'exit 1'
End
End

Describe 'Nix installation'
It 'checks if nix command exists'
When run bash -c "grep 'command -v nix' '$SCRIPT'"
The output should include 'command -v nix'
End

It 'uses Determinate Systems installer'
When run bash -c "grep 'install.determinate.systems' '$SCRIPT'"
The output should include 'install.determinate.systems/nix'
End

It 'handles both macOS and Linux installations'
When run bash -c "grep -c 'install.determinate.systems/nix' '$SCRIPT'"
The output should eq '3'
End

It 'sources Nix profile after installation'
When run bash -c "grep 'profile.d/nix' '$SCRIPT'"
The output should include 'nix-daemon.sh'
End
End

Describe 'USER variable handling'
It 'sets USER from id command when not set'
When run bash -c "grep 'id -un' '$SCRIPT'"
The output should include 'id -un'
End

It 'exports USER variable'
When run bash -c "grep 'export USER' '$SCRIPT'"
The output should include 'export USER'
End
End

Describe 'dotfiles repository handling'
It 'clones from shunkakinoki/dotfiles'
When run bash -c "grep 'github.com/shunkakinoki/dotfiles' '$SCRIPT'"
The output should include 'github.com/shunkakinoki/dotfiles'
End

It 'supports GITHUB_PR environment variable'
When run bash -c "grep 'GITHUB_PR' '$SCRIPT'"
The output should include 'GITHUB_PR'
End

It 'fetches PR refs when GITHUB_PR is set'
When run bash -c "grep 'refs/pull' '$SCRIPT'"
The output should include 'refs/pull'
End

It 'defines DOTFILES_DIR as HOME/dotfiles'
When run bash -c "grep 'DOTFILES_DIR=' '$SCRIPT'"
The output should include '$HOME/dotfiles'
End
End

Describe 'make installation'
It 'checks for make command'
When run bash -c "grep 'command -v make' '$SCRIPT'"
The output should include 'command -v make'
End

It 'runs make install'
When run bash -c "grep 'make install' '$SCRIPT'"
The output should include 'make install'
End
End

Describe 'Docker support'
It 'checks for IN_DOCKER environment variable'
When run bash -c "grep 'IN_DOCKER' '$SCRIPT'"
The output should include 'IN_DOCKER'
End

It 'uses --init none for Docker installations'
When run bash -c "grep '\-\-init none' '$SCRIPT'"
The output should include '--init none'
End
End

End
