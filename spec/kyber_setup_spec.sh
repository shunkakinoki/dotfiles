#!/usr/bin/env bash
# shellcheck disable=SC2329

Describe 'kyber/setup.sh'
SCRIPT="$PWD/named-hosts/kyber/setup.sh"

Describe 'script structure'
It 'uses bash shebang'
When run bash -c "head -1 '$SCRIPT'"
The output should include '#!/bin/bash'
End

It 'exits on error (set -e)'
When run bash -c "head -10 '$SCRIPT'"
The output should include 'set -e'
End
End

Describe 'Tailscale installation logic'
It 'checks if tailscale command exists'
When run bash -c "grep 'command -v tailscale' '$SCRIPT'"
The output should include 'command -v tailscale'
End

It 'uses Tailscale official installer'
When run bash -c "grep 'tailscale.com/install.sh' '$SCRIPT'"
The output should include 'tailscale.com/install.sh'
End
End

Describe 'systemd integration'
It 'enables tailscaled service'
When run bash -c "grep 'systemctl enable' '$SCRIPT'"
The output should include 'tailscaled'
End

It 'uses --now flag to start immediately'
When run bash -c "grep 'systemctl enable' '$SCRIPT'"
The output should include '--now'
End

It 'runs tailscale up'
When run bash -c "grep 'tailscale up' '$SCRIPT'"
The output should include 'tailscale up'
End

It 'shows tailscale status'
When run bash -c "grep 'tailscale status' '$SCRIPT'"
The output should include 'tailscale status'
End
End

Describe 'output messages'
It 'shows setup message'
When run bash -c "grep 'Setting up Kyber' '$SCRIPT'"
The output should include 'Setting up Kyber'
End

It 'shows Tailscale install message'
When run bash -c "grep 'Installing Tailscale' '$SCRIPT'"
The output should include 'Installing Tailscale'
End

It 'shows Tailscale connection message'
When run bash -c "grep 'Connecting to Tailscale' '$SCRIPT'"
The output should include 'Connecting to Tailscale'
End
End

End
