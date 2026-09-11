#!/usr/bin/env bash

Describe 'Nix-managed beads'

FLAKE="$PWD/flake.nix"
OVERLAY="$PWD/overlays/default.nix"
PACKAGES="$PWD/home-manager/packages/default.nix"
MODULE="$PWD/home-manager/modules/beads/default.nix"
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

It 'owns the ~/.local/bin entries that outrank the nix profile'
When run bash -c "grep -F 'home.file.\".local/bin/bd\".source = \"\${pkgs.beads}/bin/bd\"' \"$MODULE\" >/dev/null && grep -F 'home.file.\".local/bin/beads\".source = \"\${pkgs.beads}/bin/beads\"' \"$MODULE\" >/dev/null"
The status should be success
End

It 'imports the beads module'
When run grep -Fx '  ./beads' "$MODULES"
The output should include './beads'
End

It 'no longer builds bd through update-local-binaries.sh'
When run grep -F 'steveyegge/beads' "$LOCAL_BINARIES"
The status should not be success
End

End
