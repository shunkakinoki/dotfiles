#!/usr/bin/env bash
# shellcheck disable=SC2016

Describe 'Paperclip service'
NIX_MODULE="$PWD/home-manager/services/paperclip/default.nix"
START_SCRIPT="$PWD/home-manager/services/paperclip/start.sh"

It 'is enabled only on Kyber Linux'
When run grep 'pkgs.stdenv.hostPlatform.isLinux && host.isKyber' "$NIX_MODULE"
The output should include 'pkgs.stdenv.hostPlatform.isLinux && host.isKyber'
End

It 'starts after Docker and CLIProxyAPI through the shared Docker group wrapper'
When run bash -c "sed -n '/systemd.user.services.paperclip =/,/Install.WantedBy/p' '$NIX_MODULE'; grep 'cpa-manager-plus/docker-start.sh' '$NIX_MODULE'"
The output should include 'docker.service'
The output should include 'cliproxyapi.service'
The output should include 'X-SwitchMethod = "restart";'
The output should include 'cpa-manager-plus/docker-start.sh'
End

It 'runs the upstream image on the host network with a persistent home'
When run grep -E 'ghcr.io/paperclipai/paperclip:latest|--network host|DATA_DIR:/paperclip' "$START_SCRIPT"
The output should include 'ghcr.io/paperclipai/paperclip:latest'
The output should include '--network host'
The output should include '$DATA_DIR:/paperclip'
End

It 'routes agent CLIs through the local CLIProxyAPI without exposing the key on the command line'
When run grep -E 'PAPERCLIP_CLIPROXY_URL|ANTHROPIC_BASE_URL|ANTHROPIC_AUTH_TOKEN|ANTHROPIC_API_KEY=|OPENAI_BASE_URL|-e OPENAI_API_KEY' "$START_SCRIPT"
The output should include 'http://127.0.0.1:8317'
The output should include '-e ANTHROPIC_AUTH_TOKEN'
The output should include '"ANTHROPIC_API_KEY="'
The output should include '"OPENAI_BASE_URL=${CLIPROXY_URL}/v1"'
The output should not include 'AUTH_TOKEN=${CLIPROXY_API_KEY}"'
End

It 'generates required secrets once and lets the machine env override them'
When run grep -E 'GENERATED_ENV|if \[ -z "\$\{!key:-\}" \]' "$START_SCRIPT"
The output should include 'if [ ! -f "$GENERATED_ENV" ]; then'
The output should include 'if [ -z "${!key:-}" ]; then'
End

It 'restricts the persistent data directory to the service user'
When run grep -E 'umask 077|chmod 700|USER_UID=\$\(id -u\)' "$START_SCRIPT"
The output should include 'umask 077'
The output should include 'chmod 700'
The output should include 'USER_UID=$(id -u)'
End

It 'refuses to start without a CLIProxy key'
When run env HOME="$(mktemp -d)" bash -c "sed -e 's|@docker@|false|g' -e 's|@openssl@|openssl|g' '$START_SCRIPT' | env -u CLIPROXY_API_KEY bash"
The status should be failure
The error should include 'CLIPROXY_API_KEY is not set'
End
End
