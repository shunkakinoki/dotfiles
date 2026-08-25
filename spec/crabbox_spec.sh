#!/usr/bin/env bash
# shellcheck disable=SC2016

Describe 'Crabbox CLI and kyber coordinator service'
OVERLAY="$PWD/overlays/default.nix"
PACKAGES="$PWD/home-manager/packages/default.nix"
HOMEBREW="$PWD/nix-darwin/config/homebrew.nix"
MODULE="$PWD/home-manager/services/crabbox/default.nix"
START_SCRIPT="$PWD/home-manager/services/crabbox/start.sh"
DOCKER_START_SCRIPT="$PWD/home-manager/services/crabbox/docker-start.sh"

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

It 'keeps CLI installation out of the service definition'
When run cat "$MODULE"
The output should not include 'home.packages'
The output should not include 'fetchurl'
The output should include 'version = pkgs.crabbox.version'
End

It 'enables the coordinator only on kyber Linux'
When run grep 'pkgs.stdenv.isLinux && host.isKyber' "$MODULE"
The output should include 'pkgs.stdenv.isLinux && host.isKyber'
End

It 'builds the official coordinator from the pinned release revision'
When run grep -E 'SOURCE_REVISION|SOURCE_CONTEXT|Dockerfile|docker@ build' "$START_SCRIPT"
The output should include 'SOURCE_REVISION="@source_revision@"'
The output should include 'openclaw/crabbox.git'
The output should include '@docker@ build --pull'
End

It 'keeps the coordinator loopback-only and verifies liveness and readiness'
When run grep -E '127.0.0.1:8080|/v1/health|/v1/ready' "$START_SCRIPT"
The output should include '--publish 127.0.0.1:8080:8080'
The output should include '/v1/health'
The output should include '/v1/ready'
End

It 'creates private generated secrets without printing the dotenv'
When run grep -E 'umask 077|chmod 600|Never print' "$START_SCRIPT"
The output should include 'umask 077'
The output should include 'chmod 600'
The output should include 'Never print'
End

It 'falls back to the host Docker group wrappers'
When run grep -E '/run/wrappers/bin/sg|/usr/bin/sg' "$DOCKER_START_SCRIPT"
The output should include '/run/wrappers/bin/sg'
The output should include '/usr/bin/sg'
End
End
