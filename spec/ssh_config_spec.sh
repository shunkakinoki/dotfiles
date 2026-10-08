#!/usr/bin/env bash
# shellcheck disable=SC2016,SC2329

Describe 'home-manager/programs/ssh/default.nix'
SSH_CONFIG_NIX="$PWD/home-manager/programs/ssh/default.nix"

Describe 'andor host'
It 'uses the Andor Tailscale DNS name'
When run bash -c "grep -A2 '\"andor\" = {' '$SSH_CONFIG_NIX'"
The output should include 'andor.tail950b36.ts.net'
The output should include 'User = "ubuntu"'
End
End

Describe 'kamino family'
It 'derives SSH hosts from the generated family rather than per-host stanzas'
When run cat home-manager/programs/kamino/default.nix
The output should include 'fleet.nix'
The output should include 'HostName = machine.hostname'
The output should include 'User = machine.user'
The output should include 'fleet.machines'
End

It 'pins each host key under its tailnet address, so IP-reached fleet commands verify'
When run bash -c "nix-instantiate --eval --strict --raw home-manager/programs/ssh/known-hosts.nix > \"\$SHELLSPEC_TMPBASE/known_hosts\"; for n in 1 2 3 4 5 6 7 8 9 10; do name=\$(ssh-keygen -F kamino\$n.tail950b36.ts.net -f \"\$SHELLSPEC_TMPBASE/known_hosts\" | awk '!/^#/ {print \$3}'); addr=\$(grep -oE \"kamino\$n = \\\"[0-9.]+\" home-manager/programs/ssh/known-hosts.nix | grep -oE '[0-9.]+\$'); ip=\$(ssh-keygen -F \"\$addr\" -f \"\$SHELLSPEC_TMPBASE/known_hosts\" | awk '!/^#/ {print \$3}'); [ -n \"\$name\" ] && [ \"\$name\" = \"\$ip\" ] && echo pinned; done | grep -c pinned; ssh-keygen -F 100.127.59.11 -f \"\$SHELLSPEC_TMPBASE/known_hosts\" | awk '!/^#/' | ssh-keygen -lf -"
The output should start with '10'
The output should include 'SHA256:hUFEw+kspXMRugKvSnhuWx5p4hfej0tnRO4Tc6oQ2/g'
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

Describe 'galactica host'
It 'pins the current native OpenSSH host key'
When run bash -c "grep '^galactica.tail950b36.ts.net ssh-ed25519 ' home-manager/programs/ssh/known_hosts | ssh-keygen -lf -"
The output should include 'SHA256:1W+X5BCZQYDQnlZp/9bAg+hkGbps27w04wies+BJTb8'
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

It 'pins the current native OpenSSH host key'
When run bash -c "grep '^matic.tail950b36.ts.net ssh-ed25519 ' home-manager/programs/ssh/known_hosts | ssh-keygen -lf -"
The output should include 'SHA256:5oy61cZd6zSF6vrEcSRG6olYvfogp+qkJB14sOPaTVY'
End

It 'pins the tailnet address to the same key, so IP-reached fleet commands verify'
When run bash -c "grep '^100.76.48.66 ssh-ed25519 ' home-manager/programs/ssh/known_hosts | ssh-keygen -lf -"
The output should include 'SHA256:5oy61cZd6zSF6vrEcSRG6olYvfogp+qkJB14sOPaTVY'
End
End
End
