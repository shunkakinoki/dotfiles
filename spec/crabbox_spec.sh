#!/usr/bin/env bash
# shellcheck disable=SC2016

Describe 'Crabbox installation and kyber services'
OVERLAY="$PWD/overlays/default.nix"
PACKAGES="$PWD/home-manager/packages/default.nix"
PACKAGE_JSON="$PWD/package.json"
HOMEBREW="$PWD/nix-darwin/config/homebrew.nix"
SERVICE_MODULE="$PWD/home-manager/services/crabbox/default.nix"
SERVICE_INDEX="$PWD/home-manager/services/default.nix"
MAKEFILE="$PWD/Makefile"
LOCAL_BINARIES="$PWD/.local-binaries.txt"
ULB="$PWD/scripts/update-local-binaries.sh"
START="$PWD/home-manager/services/crabbox/start.sh"
POSTGRES_INIT="$PWD/home-manager/services/crabbox/init-postgres.sh"
HEALTH_CHECK="$PWD/home-manager/services/crabbox/health-check.sh"

It 'packages the CLI independently in the shared overlay'
When run bash -c "sed -n '/crabbox = prev.stdenvNoCC.mkDerivation rec {/,/meta.mainProgram = \"crabbox\"/p' '$OVERLAY'"
The output should include 'version = "0.47.0"'
The output should include 'crabbox_${version}'
The output should include 'crabbox-apple-vm-helper'
The output should include 'meta.mainProgram = "crabbox"'
End

It 'installs the CLI through each platform package layer'
When run bash -c "grep -Fx '  crabbox' '$PACKAGES'; grep -Fx '      \"crabbox\"' '$HOMEBREW'"
The output should include '  crabbox'
The output should include '      "crabbox"'
End

It 'packages the official Blacksmith Testbox CLI outside npm'
When run bash -c "sed -n '/blacksmith-testbox-cli = prev.stdenvNoCC.mkDerivation rec {/,/meta.mainProgram = \"blacksmith\"/p' '$OVERLAY'; grep -Fx '  blacksmith-testbox-cli' '$PACKAGES'; grep -F '\"blacksmith-cli\"' '$PACKAGE_JSON' || true"
The output should include 'version = "0.4.57"'
The output should include 'clireleases.blacksmith.sh'
The output should include 'meta.mainProgram = "blacksmith"'
The output should include '  blacksmith-testbox-cli'
The output should not include '"blacksmith-cli"'
End

It 'builds the Node coordinator through ulb'
When run bash -c "cat '$LOCAL_BINARIES'; cat '$ULB'"
The output should include 'openclaw/crabbox/worker/dist-node/crabbox-coordinator#node-build'
The output should include 'npm ci 2>&1 && npm run build:node'
The output should include 'dist-node/server.mjs'
End

It 'registers a kyber-only host service separately from installation'
When run bash -c "cat '$SERVICE_INDEX'; cat '$SERVICE_MODULE'"
The output should include 'crabbox = ./crabbox;'
The output should include 'lib.mkIf (isKyber && pkgs.stdenv.hostPlatform.isLinux)'
The output should include 'systemd.user.services.crabbox-postgres'
The output should include 'systemd.user.services.crabbox'
The output should include 'Requires = [ "crabbox-postgres.service" ]'
End

It 'restarts PostgreSQL and the coordinator through the service hook'
When run bash -c "cat '$MAKEFILE'"
The output should include 'systemctl --user restart crabbox-postgres.service crabbox.service'
End

It 'runs the upstream Node coordinator directly without containers or Kubernetes'
When run bash -c "cat '$SERVICE_MODULE' '$START' '$POSTGRES_INIT'"
The output should include 'dist-node/crabbox-coordinator'
The output should include 'postgresql_18'
The output should not include 'docker'
The output should not include 'Dockerfile'
The output should not include 'kubernetes'
End

It 'keeps PostgreSQL private and verifies both coordinator probes'
When run bash -c "cat '$SERVICE_MODULE' '$START' '$HEALTH_CHECK'"
The output should include '-h 127.0.0.1'
The output should include 'DATABASE_URL="postgresql://crabbox:'
The output should include '/v1/health'
The output should include '/v1/ready'
End

It 'lets Cloudflare own the public portal origin and trusts only the Kyber proxy paths'
When run bash -c "cat '$START'"
The output should not include 'CRABBOX_PUBLIC_URL'
The output should include 'CRABBOX_TRUSTED_PROXY_CIDRS'
The output should include '127.0.0.1/32,10.42.1.0/24'
The output should include '10.42.1.0/24'
The output should include 'CRABBOX_TRUSTED_USER_HEADER'
The output should include 'Cf-Access-Authenticated-User-Email'
The output should include 'CRABBOX_TRUSTED_USER_ORG'
The output should include 'CRABBOX_ACCESS_TEAM_DOMAIN'
The output should include 'shunkakinoki.cloudflareaccess.com'
End

It 'generates local secrets without requiring a provider token'
When run bash -c "cat '$START'"
The output should include 'CRABBOX_SHARED_TOKEN'
The output should include 'CRABBOX_ADMIN_TOKEN'
The output should include 'CRABBOX_SESSION_SECRET'
The output should not include 'HETZNER_TOKEN'
End

It 'uses strict mode in every service script'
When run bash -c "head -3 '$START'; head -3 '$POSTGRES_INIT'; head -3 '$HEALTH_CHECK'"
The output should include 'set -euo pipefail'
End
End
