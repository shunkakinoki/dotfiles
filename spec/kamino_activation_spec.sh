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

It 'rejects an unknown activation phase'
When run run_phase unknown
The status should be failure
The error should include 'Unknown Kamino activation phase'
End
End
