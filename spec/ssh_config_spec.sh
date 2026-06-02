#!/usr/bin/env bash
# shellcheck disable=SC2329

Describe 'home-manager/programs/ssh/default.nix'
SSH_CONFIG_NIX="$PWD/home-manager/programs/ssh/default.nix"

Describe 'kyber host'
It 'uses the Tailscale DNS name instead of a stale tailnet IP'
When run bash -c "grep 'HostName =' '$SSH_CONFIG_NIX' | grep kyber"
The output should include 'kyber.tail950b36.ts.net'
The output should not include '100.74.174.97'
End

It 'pins the Codex-compatible SSH identity'
When run cat "$SSH_CONFIG_NIX"
The output should include 'IdentityFile = "~/.ssh/id_rsa"'
The output should include 'IdentitiesOnly = "yes"'
End
End
End
