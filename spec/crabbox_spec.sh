#!/usr/bin/env bash
# shellcheck disable=SC2016

Describe 'Crabbox CLI installation'
OVERLAY="$PWD/overlays/default.nix"
PACKAGES="$PWD/home-manager/packages/default.nix"
HOMEBREW="$PWD/nix-darwin/config/homebrew.nix"
SERVICE_MODULE="$PWD/home-manager/services/crabbox/default.nix"

It 'packages the CLI independently in the shared overlay'
When run bash -c "sed -n '/crabbox = prev.stdenvNoCC.mkDerivation rec {/,/meta.mainProgram = \"crabbox\"/p' '$OVERLAY'"
The output should include 'version = "0.46.0"'
The output should include 'crabbox_${version}'
The output should include 'meta.mainProgram = "crabbox"'
End

It 'installs the CLI through each platform package layer'
When run bash -c "grep -Fx '  crabbox' '$PACKAGES'; grep -Fx '      \"crabbox\"' '$HOMEBREW'"
The output should include '  crabbox'
The output should include '      "crabbox"'
End

It 'does not define a host coordinator service'
When run test ! -e "$SERVICE_MODULE"
The status should be success
End
End
