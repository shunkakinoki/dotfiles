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
  cat >"$TEST_ROOT/bin/npx" <<'EOF'
#!/usr/bin/env bash
printf 'npx %s\n' "$*" >>"$COMMAND_LOG"
case "$*" in
  *"service install"*)
    if [ "${T3_INSTALL_EXIT:-0}" != 0 ]; then exit "$T3_INSTALL_EXIT"; fi
    ;;
esac
exit 0
EOF
  printf '/bin/bash\n' >"$TEST_ROOT/root-shell"
  cat >"$TEST_ROOT/bin/getent" <<EOF
#!/usr/bin/env bash
[ "\$*" = 'passwd root' ] && printf 'root:x:0:0:root:/root:%s\\n' "\$(/bin/cat '$TEST_ROOT/root-shell')"
EOF
  cat >"$TEST_ROOT/bin/chsh" <<EOF
#!/usr/bin/env bash
printf 'chsh %s\\n' "\$*" >>"\$COMMAND_LOG"
printf '%s\\n' "\$2" >'$TEST_ROOT/root-shell'
EOF
  chmod +x "$TEST_ROOT/bin"/*
  printf '#!/bin/sh\n' >"$TEST_ROOT/fish"
  chmod +x "$TEST_ROOT/fish"
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

It 'starts the Herdr server after reloading user units'
When run run_phase start-herdr "$TEST_ROOT/bin/systemctl"
The status should be success
The contents of file "$TEST_ROOT/commands" should equal $'systemctl --user daemon-reload\nsystemctl --user enable --now herdr-server.service'
End

It 'lists fish and makes it the root login shell when root is on bash'
printf '/bin/sh\n/bin/bash\n%s\n' "$TEST_ROOT/fish-lsp" >"$TEST_ROOT/shells"
When run run_phase login-shell "$TEST_ROOT/fish" "$TEST_ROOT/shells"
The status should be success
The line 1 of output should equal "Added $TEST_ROOT/fish to $TEST_ROOT/shells."
The line 2 of output should equal "Set root's login shell to $TEST_ROOT/fish."
The contents of file "$TEST_ROOT/shells" should equal "$(printf '/bin/sh\n/bin/bash\n%s\n%s' "$TEST_ROOT/fish-lsp" "$TEST_ROOT/fish")"
The contents of file "$TEST_ROOT/commands" should equal "chsh -s $TEST_ROOT/fish root"
End

It 'changes only the login shell when fish is already listed'
printf '/bin/bash\n%s\n' "$TEST_ROOT/fish" >"$TEST_ROOT/shells"
When run run_phase login-shell "$TEST_ROOT/fish" "$TEST_ROOT/shells"
The status should be success
The output should equal "Set root's login shell to $TEST_ROOT/fish."
The contents of file "$TEST_ROOT/shells" should equal "$(printf '/bin/bash\n%s' "$TEST_ROOT/fish")"
The contents of file "$TEST_ROOT/commands" should equal "chsh -s $TEST_ROOT/fish root"
End

It 'makes no changes once fish is listed and is the root login shell'
printf '/bin/bash\n%s\n' "$TEST_ROOT/fish" >"$TEST_ROOT/shells"
printf '%s\n' "$TEST_ROOT/fish" >"$TEST_ROOT/root-shell"
When run run_phase login-shell "$TEST_ROOT/fish" "$TEST_ROOT/shells"
The status should be success
The output should be blank
The contents of file "$TEST_ROOT/shells" should equal "$(printf '/bin/bash\n%s' "$TEST_ROOT/fish")"
The path "$TEST_ROOT/commands" should not be exist
End

It 'refuses a missing fish without changing the login shell'
printf '/bin/bash\n' >"$TEST_ROOT/shells"
When run run_phase login-shell "$TEST_ROOT/missing-fish" "$TEST_ROOT/shells"
The status should be failure
The error should include "Refusing to change root's login shell: $TEST_ROOT/missing-fish"
The contents of file "$TEST_ROOT/shells" should equal '/bin/bash'
The path "$TEST_ROOT/commands" should not be exist
End

It 'refuses a non-executable fish without changing the login shell'
printf '/bin/bash\n' >"$TEST_ROOT/shells"
: >"$TEST_ROOT/plain-fish"
When run run_phase login-shell "$TEST_ROOT/plain-fish" "$TEST_ROOT/shells"
The status should be failure
The error should include "Refusing to change root's login shell: $TEST_ROOT/plain-fish"
The contents of file "$TEST_ROOT/shells" should equal '/bin/bash'
The path "$TEST_ROOT/commands" should not be exist
End

It 'enrolls Tailscale with the supplied arguments'
When run bash -c "PATH='$TEST_ROOT/bin:/usr/bin:/bin' COMMAND_LOG='$TEST_ROOT/commands' bash '$SCRIPT' tailscale kamino100 '$TEST_ROOT/bin/tailscale' --hostname=kamino100 --accept-dns=true --ssh=true"
The status should be success
The output should include 'Tailscale enrollment'
The contents of file "$TEST_ROOT/commands" should include 'tailscale up --hostname=kamino100 --accept-dns=true --ssh=true'
End

It 'provisions publish-only T3 Connect with the device flow on first run'
When run env T3CODE_HOME="$TEST_ROOT/fresh-t3" PATH="$TEST_ROOT/bin:/usr/bin:/bin" COMMAND_LOG="$TEST_ROOT/commands" bash "$SCRIPT" t3-connect "$TEST_ROOT/bin/t3"
The status should be success
The output should include 'T3 Connect publish-only link requested.'
The contents of file "$TEST_ROOT/commands" should include 't3@nightly service install'
The contents of file "$TEST_ROOT/commands" should include 't3 connect link --headless --publish-only'
The contents of file "$TEST_ROOT/commands" should include 'systemctl --user restart t3code.service'
The stderr should include 'bootstrapping with t3@nightly'
End

It 'lets a piped first switch finish before T3 device authorization'
When run env KAMINO_T3_CONNECT_DEFER=1 T3CODE_HOME="$TEST_ROOT/fresh-t3" PATH="$TEST_ROOT/bin:/usr/bin:/bin" COMMAND_LOG="$TEST_ROOT/commands" bash "$SCRIPT" t3-connect "$TEST_ROOT/bin/t3"
The status should be success
The stderr should include 'T3 Connect authorization deferred'
The contents of file "$TEST_ROOT/commands" should include 't3@nightly service install'
The contents of file "$TEST_ROOT/commands" should include 'systemctl --user enable --now t3code.service'
The contents of file "$TEST_ROOT/commands" should not include 't3 connect link'
End

It 'provisions a managed T3 Connect tunnel for opted-in hosts'
mkdir -p "$TEST_ROOT/t3/runtime" "$TEST_ROOT/t3/userdata/secrets"
printf '{\n  "protocol": 3\n}\n' >"$TEST_ROOT/t3/runtime/service-state.json"
: >"$TEST_ROOT/t3/userdata/secrets/cloud-cli-oauth-token.bin"
When run env T3CODE_HOME="$TEST_ROOT/t3" PATH="$TEST_ROOT/bin:/usr/bin:/bin" COMMAND_LOG="$TEST_ROOT/commands" bash "$SCRIPT" t3-connect "$TEST_ROOT/bin/t3" managed
The status should be success
The output should include 'T3 Connect managed link requested.'
The contents of file "$TEST_ROOT/commands" should include 't3 connect link'
The contents of file "$TEST_ROOT/commands" should not include '--publish-only'
End

It 'rejects an unknown T3 Connect mode'
When run env T3CODE_HOME="$TEST_ROOT/t3" PATH="$TEST_ROOT/bin:/usr/bin:/bin" COMMAND_LOG="$TEST_ROOT/commands" bash "$SCRIPT" t3-connect "$TEST_ROOT/bin/t3" bogus
The status should be failure
The stderr should include 'Unknown T3 Connect mode: bogus'
End

It 'leaves a protocol-3 launcher alone so the desktop client owns upgrades'
mkdir -p "$TEST_ROOT/t3/runtime" "$TEST_ROOT/t3/userdata/secrets"
printf '{\n  "protocol": 3,\n  "activeVersion": "0.0.43-nightly.20260920.2031"\n}\n' >"$TEST_ROOT/t3/runtime/service-state.json"
: >"$TEST_ROOT/t3/userdata/secrets/cloud-cli-oauth-token.bin"
When run env T3CODE_HOME="$TEST_ROOT/t3" PATH="$TEST_ROOT/bin:/usr/bin:/bin" COMMAND_LOG="$TEST_ROOT/commands" bash "$SCRIPT" t3-connect "$TEST_ROOT/bin/t3"
The status should be success
The output should include 'T3 Connect publish-only link requested.'
The contents of file "$TEST_ROOT/commands" should not include 'service install'
The contents of file "$TEST_ROOT/commands" should not include 'service update'
The contents of file "$TEST_ROOT/commands" should include 't3 connect link --publish-only'
End

It 'bootstraps a protocol-3 launcher over a stale protocol-2 state'
mkdir -p "$TEST_ROOT/t3/runtime"
printf '{\n  "protocol": 2,\n  "activeVersion": "0.0.42"\n}\n' >"$TEST_ROOT/t3/runtime/service-state.json"
When run env T3CODE_HOME="$TEST_ROOT/t3" PATH="$TEST_ROOT/bin:/usr/bin:/bin" COMMAND_LOG="$TEST_ROOT/commands" bash "$SCRIPT" t3-connect "$TEST_ROOT/bin/t3"
The status should be success
The output should include 'T3 Connect publish-only link requested.'
The contents of file "$TEST_ROOT/commands" should include 't3@nightly service install'
The stderr should include 'bootstrapping with t3@nightly'
End

It 'falls back to the nightly service update path when install fails'
When run env T3_INSTALL_EXIT=1 PATH="$TEST_ROOT/bin:/usr/bin:/bin" COMMAND_LOG="$TEST_ROOT/commands" bash "$SCRIPT" t3-connect "$TEST_ROOT/bin/t3"
The status should be success
The output should include 'T3 Connect publish-only link requested.'
The contents of file "$TEST_ROOT/commands" should include 't3@nightly service install'
The contents of file "$TEST_ROOT/commands" should include 't3@nightly service update'
The stderr should include 'bootstrapping with t3@nightly'
End

It 'links without the device flow when a credential already exists'
mkdir -p "$TEST_ROOT/t3/userdata/secrets"
: >"$TEST_ROOT/t3/userdata/secrets/cloud-cli-oauth-token.bin"
When run env T3CODE_HOME="$TEST_ROOT/t3" PATH="$TEST_ROOT/bin:/usr/bin:/bin" COMMAND_LOG="$TEST_ROOT/commands" bash "$SCRIPT" t3-connect "$TEST_ROOT/bin/t3"
The status should be success
The output should include 'T3 Connect publish-only link requested.'
The contents of file "$TEST_ROOT/commands" should include 't3 connect link --publish-only'
The contents of file "$TEST_ROOT/commands" should not include '--headless'
The stderr should include 'bootstrapping with t3@nightly'
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
