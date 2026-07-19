#!/usr/bin/env bash
# shellcheck disable=SC2329

Describe 'home-manager/programs/ssh/default.nix'
SSH_CONFIG_NIX="$PWD/home-manager/programs/ssh/default.nix"

Describe 'andor host'
It 'uses the Andor Tailscale DNS name'
When run bash -c "grep -A2 '\"andor\" = {' '$SSH_CONFIG_NIX'"
The output should include 'andor.tail950b36.ts.net'
The output should include 'User = "ubuntu"'
End
End

Describe 'kyber host'
It 'uses the Tailscale DNS name instead of a stale tailnet IP'
When run bash -c "grep 'HostName =' '$SSH_CONFIG_NIX' | grep kyber"
The output should include 'kyber.tail950b36.ts.net'
The output should not include '100.74.174.97'
End

It 'pins the Codex-compatible SSH identity'
When run cat "$SSH_CONFIG_NIX"
The output should include 'IdentityFile = [ "~/.ssh/id_rsa" ]'
The output should include 'IdentitiesOnly = "yes"'
End
End

Describe 'matic host'
It 'resolves the bare matic alias so herdr --remote matic works'
When run bash -c "grep 'HostName =' '$SSH_CONFIG_NIX' | grep matic"
The output should include 'matic.tail950b36.ts.net'
End

It 'uses the shunkakinoki login'
When run bash -c "grep -A2 '\"matic\" = {' '$SSH_CONFIG_NIX'"
The output should include 'User = "shunkakinoki"'
End
End
End
