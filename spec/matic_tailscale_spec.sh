#!/usr/bin/env bash
# shellcheck disable=SC2329

Describe 'named-hosts/matic/default.nix tailscale'
CONFIG="$PWD/named-hosts/matic/default.nix"

It 'enables the tailscale service'
When run bash -c "grep -A1 -F 'services.tailscale = {' '$CONFIG'"
The output should include 'enable = true'
End

It 'enables routing features for exit node use'
When run bash -c "grep -F 'useRoutingFeatures = \"both\";' '$CONFIG'"
The output should include 'useRoutingFeatures = "both"'
End

It 'advertises the host as an exit node'
When run bash -c "grep -F '\"--advertise-exit-node\"' '$CONFIG'"
The output should include '--advertise-exit-node'
End

It 'accepts DNS from tailscale'
When run bash -c "grep -F '\"--accept-dns=true\"' '$CONFIG'"
The output should include '--accept-dns=true'
End

It 'uses systemd-resolved for Tailscale MagicDNS'
When run bash -c "grep -F 'services.resolved.enable = true;' '$CONFIG'"
The output should include 'services.resolved.enable = true'
End

It 'routes NetworkManager DNS through systemd-resolved'
When run bash -c "grep -A2 -F 'networking.networkmanager = {' '$CONFIG'"
The output should include 'systemd-resolved'
End

It 'preserves public upstream resolvers'
When run bash -c "grep -A5 -F 'networking.nameservers = [' '$CONFIG'"
The output should include '8.8.8.8'
The output should include '1.1.1.1'
End

It 'releases the shared static resolv.conf override'
When run bash -c "grep -F 'environment.etc.\"resolv.conf\".text = lib.mkForce null;' '$CONFIG'"
The output should include 'lib.mkForce null'
End

It 'trusts the tailscale interface in the firewall'
When run bash -c "grep -F 'trustedInterfaces = [ \"tailscale0\" ];' '$CONFIG'"
The output should include 'tailscale0'
End

End
