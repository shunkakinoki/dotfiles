#!/usr/bin/env bash

Describe 'Darwin configuration activation'
SYSTEM_CONFIG="$PWD/nix-darwin/config/system.nix"
HOMEBREW_CONFIG="$PWD/nix-darwin/config/homebrew.nix"

It 'keeps macOS updates but does not fail activation when one fails'
When run bash -c "cat '$SYSTEM_CONFIG'"
The output should include 'if ! softwareupdate --all --install; then'
The output should include 'macOS software update failed; continuing activation'
End

It 'keeps Homebrew maintenance under the existing non-fatal activation guard'
When run bash -c "cat '$HOMEBREW_CONFIG'"
The output should include 'system.activationScripts.homebrew.text = lib.mkBefore'
The output should include 'set +e'
The output should include 'autoUpdate = builtins.getEnv "NIX_OFFLINE" != "1";'
The output should include 'upgrade = builtins.getEnv "NIX_OFFLINE" != "1";'
The output should include 'cleanup = "zap";'
End
End
