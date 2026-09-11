#!/usr/bin/env bash

Describe 'Nix-managed beads'

FLAKE="$PWD/flake.nix"
OVERLAY="$PWD/overlays/default.nix"
PACKAGES="$PWD/home-manager/packages/default.nix"
MODULES="$PWD/home-manager/modules/default.nix"
LOCAL_BINARIES="$PWD/.local-binaries.txt"

It 'tracks the upstream beads flake'
When run grep -F 'url = "github:gastownhall/beads"' "$FLAKE"
The output should include 'github:gastownhall/beads'
End

It 'applies the beads overlay'
When run grep -Fx '  inputs.beads.overlays.default' "$OVERLAY"
The output should include 'inputs.beads.overlays.default'
End

It 'installs beads on every host'
When run bash -c "line=\$(grep -nFx '  beads' \"$PACKAGES\" | cut -d: -f1); boundary=\$(grep -nF '++ lib.optionals stdenv.hostPlatform.isDarwin' \"$PACKAGES\" | cut -d: -f1); test -n \"\$line\" -a -n \"\$boundary\" -a \"\$line\" -lt \"\$boundary\""
The status should be success
End

# home.packages already puts bd and beads on PATH. A ~/.local/bin shim would
# only matter to outrank the nix profile, and nothing writes there any more.
It 'does not shim beads into ~/.local/bin'
When run grep -Fx '  ./beads' "$MODULES"
The status should not be success
End

It 'no longer builds bd through update-local-binaries.sh'
When run grep -F 'steveyegge/beads' "$LOCAL_BINARIES"
The status should not be success
End

End
