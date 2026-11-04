#!/usr/bin/env bash
# shellcheck disable=SC2016,SC2329

Describe 'named host identity guard'
SCRIPT="$PWD/home-manager/activation/check-host-identity.sh"
setup() {
  TEST_ROOT=$(mktemp -d)
  mkdir -p "$TEST_ROOT/bin"
  printf '#!/usr/bin/env bash\nprintf "%%s\\n" "${PHYSICAL_HOST:-beskar}"\n' >"$TEST_ROOT/bin/hostname"
  printf '#!/usr/bin/env bash\nprintf "{\\"Self\\":{\\"DNSName\\":\\"%%s\\"}}\\n" "${TAILNET_HOST:-beskar.tailnet.example}"\n' >"$TEST_ROOT/bin/tailscale"
  chmod +x "$TEST_ROOT/bin"/*
  export PATH="$TEST_ROOT/bin:$PATH"
}
cleanup() { rm -rf "$TEST_ROOT"; }
Before setup
After cleanup

It 'accepts matching physical and Tailscale host identities'
When run bash "$SCRIPT" beskar
The status should be success
End

It 'refuses a Kyber profile on Beskar independently of HOST and HOSTNAME'
When run env HOST=kyber HOSTNAME=kyber bash "$SCRIPT" kyber
The status should be failure
The stderr should include 'Refusing profile kyber on host beskar'
End

It 'uses Tailscale identity when the physical name is generic'
When run env PHYSICAL_HOST=generic-linux bash "$SCRIPT" beskar
The status should be success
End

It 'rejects conflicting machine and Tailscale identities'
When run env TAILNET_HOST=kyber.tailnet.example bash "$SCRIPT" beskar
The status should be failure
The stderr should include 'Refusing profile beskar on host kyber'
End

It 'withholds activation when neither identity can be verified'
When run env PHYSICAL_HOST=generic-linux TAILNET_HOST=unknown.example bash "$SCRIPT" beskar
The status should be failure
The stderr should include 'Cannot verify profile beskar'
End

It 'allows generic profiles without claiming a named host identity'
When run env PHYSICAL_HOST=generic-linux TAILNET_HOST=unknown.example bash "$SCRIPT" runner
The status should be success
End
End
