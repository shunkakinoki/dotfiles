#!/usr/bin/env bash

Describe 'Optional network-backed packages'

PACKAGES="$PWD/home-manager/packages/default.nix"

It 'keeps network-backed packages opt-in for resilient builds'
When run grep -F 'NIX_INCLUDE_OPTIONAL_PACKAGES' "$PACKAGES"
The output should include 'NIX_INCLUDE_OPTIONAL_PACKAGES'
End

It 'documents the group as optional registry-backed dependencies'
When run sed -n '/includeOptionalPackages/,/++ lib.optionals stdenv.hostPlatform.isDarwin/p' "$PACKAGES"
The output should include 'by default to keep builds independent of registry availability'
The output should include 'pkgs.llm-agents.antigravity-cli'
The output should include 'pkgs.llm-agents.prime-agent'
The output should include 'vector'
End

End
