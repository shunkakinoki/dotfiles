#!/usr/bin/env bash
Describe 'named-hosts/kamino/activate.sh'
SCRIPT="$PWD/named-hosts/kamino/activate.sh"

setup() {
  TEST_ROOT=$(mktemp -d)
  mkdir -p "$TEST_ROOT/bin"
  cat >"$TEST_ROOT/bin/id" <<'EOF'
#!/usr/bin/env bash
[ "${1:-}" = -u ] && printf '%s\n' "${MOCK_UID:-0}" || /usr/bin/id "$@"
EOF
  cat >"$TEST_ROOT/bin/cat" <<'EOF'
#!/usr/bin/env bash
if [ "${1:-}" = /proc/1/comm ]; then printf '%s\n' "${MOCK_INIT:-systemd}"; else /bin/cat "$@"; fi
EOF
  cat >"$TEST_ROOT/bin/ssh-keygen" <<'EOF'
#!/usr/bin/env bash
[ "${MOCK_KEYGEN_FAIL:-0}" = 1 ] && exit 1
exit 0
EOF
  for name in hostnamectl loginctl systemctl tailscale mkdir chmod touch chown; do
    if [ "$name" = mkdir ] || [ "$name" = chmod ] || [ "$name" = touch ]; then
      tool_path=$(command -v "$name")
      cat >"$TEST_ROOT/bin/$name" <<EOF
#!/usr/bin/env bash
printf '%s %s\\n' '$name' "\$*" >>"\$COMMAND_LOG"
exec $tool_path "\$@"
EOF
    else
      cat >"$TEST_ROOT/bin/$name" <<EOF
#!/usr/bin/env bash
printf '%s %s\\n' '$name' "\$*" >>"\$COMMAND_LOG"
exit 0
EOF
    fi
  done
  cat >"$TEST_ROOT/bin/t3" <<'EOF'
#!/usr/bin/env bash
printf 't3 %s\n' "$*" >>"$COMMAND_LOG"
if [ "$1 $2" = "service install" ] && [ "${T3_INSTALL_EXIT:-0}" != 0 ]; then
  exit "$T3_INSTALL_EXIT"
fi
exit 0
EOF
  chmod +x "$TEST_ROOT/bin"/*
  printf 'kamino100\n' >"$TEST_ROOT/identity"
  printf 'ssh-ed25519 AAAAexample\n' >"$TEST_ROOT/client.pub"
}
cleanup() { rm -rf "$TEST_ROOT"; }
Before setup
After cleanup

run_phase() {
  PATH="$TEST_ROOT/bin:/usr/bin:/bin" COMMAND_LOG="$TEST_ROOT/commands" bash "$SCRIPT" "$@"
}

It 'checks identity without writing'
When run run_phase check kamino100 "$TEST_ROOT/identity"
The status should be success
The path "$TEST_ROOT/commands" should not be exist
End

It 'rejects a non-root install'
When run env MOCK_UID=1000 PATH="$TEST_ROOT/bin:/usr/bin:/bin" COMMAND_LOG="$TEST_ROOT/commands" bash "$SCRIPT" check kamino100 "$TEST_ROOT/identity"
The status should be failure
The error should include 'requires root'
End

It 'rejects a renamed or non-systemd install'
When run bash -c "printf 'kamino1\\n' > '$TEST_ROOT/identity'; MOCK_INIT=systemd MOCK_UID=0 PATH='$TEST_ROOT/bin:/usr/bin:/bin' COMMAND_LOG='$TEST_ROOT/commands' bash '$SCRIPT' check kamino100 '$TEST_ROOT/identity'"
The status should be failure
The error should include 'Refusing to rename'
End

It 'runs user manager commands in order'
When run run_phase user-manager kamino100
The status should be success
The contents of file "$TEST_ROOT/commands" should equal $'hostnamectl set-hostname kamino100\nloginctl enable-linger root\nsystemctl start user@0.service'
End

It 'enrolls Tailscale with the supplied arguments'
When run bash -c "PATH='$TEST_ROOT/bin:/usr/bin:/bin' COMMAND_LOG='$TEST_ROOT/commands' bash '$SCRIPT' tailscale kamino100 '$TEST_ROOT/bin/tailscale' --hostname=kamino100 --accept-dns=true --ssh=true"
The status should be success
The output should include 'Tailscale enrollment'
The contents of file "$TEST_ROOT/commands" should include 'tailscale up --hostname=kamino100 --accept-dns=true --ssh=true'
End

It 'authorizes a public key without duplicating it'
When run bash -c "PATH='$TEST_ROOT/bin:/usr/bin:/bin' COMMAND_LOG='$TEST_ROOT/commands' bash '$SCRIPT' authorize-ssh '$TEST_ROOT/client.pub' '$TEST_ROOT/ssh' '$TEST_ROOT/bin/ssh-keygen'"
The status should be success
The contents of file "$TEST_ROOT/ssh/authorized_keys" should include 'ssh-ed25519 AAAAexample'
End

It 'provisions publish-only T3 Connect with the device flow on first run'
When run env T3CODE_HOME="$TEST_ROOT/fresh-t3" PATH="$TEST_ROOT/bin:/usr/bin:/bin" COMMAND_LOG="$TEST_ROOT/commands" bash "$SCRIPT" t3-connect "$TEST_ROOT/bin/t3"
The status should be success
The output should include 'T3 Connect publish-only link requested.'
The contents of file "$TEST_ROOT/commands" should include 't3 service install'
The contents of file "$TEST_ROOT/commands" should include 't3 connect link --headless --publish-only'
The contents of file "$TEST_ROOT/commands" should include 'systemctl --user restart t3code.service'
End

It 'falls back to the service update path when install fails'
When run env T3_INSTALL_EXIT=1 PATH="$TEST_ROOT/bin:/usr/bin:/bin" COMMAND_LOG="$TEST_ROOT/commands" bash "$SCRIPT" t3-connect "$TEST_ROOT/bin/t3"
The status should be success
The output should include 'T3 Connect publish-only link requested.'
The contents of file "$TEST_ROOT/commands" should include 't3 service install'
The contents of file "$TEST_ROOT/commands" should include 't3 service update'
End

It 'links without the device flow when a credential already exists'
mkdir -p "$TEST_ROOT/t3/userdata/secrets"
: >"$TEST_ROOT/t3/userdata/secrets/cloud-cli-oauth-token.bin"
When run env T3CODE_HOME="$TEST_ROOT/t3" PATH="$TEST_ROOT/bin:/usr/bin:/bin" COMMAND_LOG="$TEST_ROOT/commands" bash "$SCRIPT" t3-connect "$TEST_ROOT/bin/t3"
The status should be success
The output should include 'T3 Connect publish-only link requested.'
The contents of file "$TEST_ROOT/commands" should include 't3 connect link --publish-only'
The contents of file "$TEST_ROOT/commands" should not include '--headless'
End

It 'skips T3 Connect provisioning when t3 is not installed'
When run run_phase t3-connect "$TEST_ROOT/missing-t3"
The status should be success
The error should include 'skipping T3 Connect'
The path "$TEST_ROOT/commands" should not be exist
End

It 'rejects an unknown activation phase'
When run run_phase unknown
The status should be failure
The error should include 'Unknown Kamino activation phase'
End
End
