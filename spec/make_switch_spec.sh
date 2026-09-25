#!/usr/bin/env bash
# shellcheck disable=SC2016,SC2329

Describe 'Makefile switch post-activation dependencies'
MAKEFILE="$PWD/Makefile"

It 'uses a switch-specific checked-in dotagents sync'
When run grep 'dotagents-switch-sync' "$MAKEFILE"
The output should include 'dotagents-switch-sync'
End

It 'initializes dotagents before syncing it'
When run bash -c "grep -A8 '^dotagents-prepare:' '$MAKEFILE'"
The output should include 'git submodule update --init dotagents'
End

It 'does not require the optional dotagents sync target during switch'
When run bash -c "grep -A2 '^dotagents-switch-sync:' '$MAKEFILE'"
The output should include 'DOTAGENTS_SKIP_SYNC=1'
End

It 'serializes Linux switches with the dotfiles-updater lock'
When run bash -c "sed -n '/^switch:/,/^else\$/p' '$MAKEFILE'"
The output should include '/run/user/$$(id -u)'
The output should include 'dotfiles-switch.lock'
The output should include 'flock "$$lock" $(MAKE) apply-switch'
End

It 'runs Darwin switches without the lock'
When run bash -c "sed -n '/^switch:/,/^endif\$/p' '$MAKEFILE' | sed -n '/^else\$/,/^endif\$/p'"
The output should include '$(MAKE) apply-switch'
The output should not include 'flock'
End

It 'keeps the switch steps behind the lock'
When run bash -c "grep '^apply-switch:' '$MAKEFILE'"
The output should include 'nix-switch services nvim-plugins-install dotagents-switch-sync'
End
End
