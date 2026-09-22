#!/usr/bin/env bash
Describe 'home-manager/activation/authorize-ssh-keys.sh'
SCRIPT="$PWD/home-manager/activation/authorize-ssh-keys.sh"

setup() {
  TEST_ROOT=$(mktemp -d)
  mkdir -p "$TEST_ROOT/bin" "$TEST_ROOT/ssh"
  cat >"$TEST_ROOT/bin/ssh-keygen" <<'EOF'
#!/usr/bin/env bash
grep -q INVALID && exit 1
exit 0
EOF
  chmod +x "$TEST_ROOT/bin/ssh-keygen"
  printf '%s\n' \
    'ssh-ed25519 AAAAcore1 core1' \
    'ssh-ed25519 AAAAcore2 core2' \
    >"$TEST_ROOT/keys"
}
cleanup() { rm -rf "$TEST_ROOT"; }
Before setup
After cleanup

It 'adds every declared key and preserves unmanaged entries'
printf '%s\n' 'ssh-ed25519 AAAAprovider provider' >"$TEST_ROOT/ssh/authorized_keys"
When run bash "$SCRIPT" "$TEST_ROOT/keys" "$TEST_ROOT/ssh" "$TEST_ROOT/bin/ssh-keygen"
The status should be success
The contents of file "$TEST_ROOT/ssh/authorized_keys" should include 'ssh-ed25519 AAAAprovider provider'
The contents of file "$TEST_ROOT/ssh/authorized_keys" should include 'ssh-ed25519 AAAAcore1 core1'
The contents of file "$TEST_ROOT/ssh/authorized_keys" should include 'ssh-ed25519 AAAAcore2 core2'
End

It 'is idempotent across repeated activations'
bash "$SCRIPT" "$TEST_ROOT/keys" "$TEST_ROOT/ssh" "$TEST_ROOT/bin/ssh-keygen"
bash "$SCRIPT" "$TEST_ROOT/keys" "$TEST_ROOT/ssh" "$TEST_ROOT/bin/ssh-keygen"
When run bash -c "test \"\$(grep -cxF 'ssh-ed25519 AAAAcore1 core1' '$TEST_ROOT/ssh/authorized_keys')\" = 1 && test \"\$(grep -cxF 'ssh-ed25519 AAAAcore2 core2' '$TEST_ROOT/ssh/authorized_keys')\" = 1"
The status should be success
End

It 'rejects an invalid declared key'
printf '%s\n' 'ssh-ed25519 AAAAprovider provider' >"$TEST_ROOT/ssh/authorized_keys"
printf '%s\n' 'INVALID key' >"$TEST_ROOT/keys"
When run bash "$SCRIPT" "$TEST_ROOT/keys" "$TEST_ROOT/ssh" "$TEST_ROOT/bin/ssh-keygen"
The status should be failure
The contents of file "$TEST_ROOT/ssh/authorized_keys" should equal 'ssh-ed25519 AAAAprovider provider'
End
End
