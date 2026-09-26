#!/usr/bin/env bash
# shellcheck disable=SC2329

Describe 'Shell LD_LIBRARY_PATH scope'
It 'exports the full Nix library set only on NixOS in bash, zsh, and fish'
When run bash -c "grep -c 'if \[ -f /etc/NIXOS \]; then' home-manager/programs/bash/default.nix home-manager/programs/zsh/default.nix; grep -c 'if test -f /etc/NIXOS' home-manager/programs/fish/default.nix"
The output should equal "$(printf 'home-manager/programs/bash/default.nix:2\nhome-manager/programs/zsh/default.nix:1\n1')"
End

It 'exposes only the GCC runtime on other Linux distributions'
When run bash -c "grep -hE '^ +(export LD_LIBRARY_PATH=|set -gx LD_LIBRARY_PATH )\"\\$\\{pkgs.stdenv.cc.cc.lib\\}/lib' home-manager/programs/bash/default.nix home-manager/programs/zsh/default.nix home-manager/programs/fish/default.nix | wc -l"
The output should equal 4
End
End
