#!/usr/bin/env bash
# shellcheck disable=SC2329
Describe 'named-hosts/beskar/activate-t3-runtime-libs.sh'
SCRIPT="$PWD/named-hosts/beskar/activate-t3-runtime-libs.sh"

setup() {
  TEST_ROOT=$(mktemp -d)
  mkdir -p "$TEST_ROOT/bin"
  COMMAND_LOG="$TEST_ROOT/commands.log"
  : >"$COMMAND_LOG"
  cat >"$TEST_ROOT/bin/dpkg-query" <<'EOF'
#!/usr/bin/env bash
printf '%s' "${MOCK_STATUS:-}"
[ -n "${MOCK_STATUS:-}" ]
EOF
  cat >"$TEST_ROOT/bin/id" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "${MOCK_UID:-1000}"
EOF
  for name in sudo apt-get; do
    cat >"$TEST_ROOT/bin/$name" <<EOF
#!/usr/bin/env bash
printf '%s %s\\n' '$name' "\$*" >>"\$COMMAND_LOG"
[ '$name' = sudo ] && exec "\$@"
exit 0
EOF
  done
  chmod +x "$TEST_ROOT"/bin/*
  export COMMAND_LOG
}

cleanup() {
  rm -rf "$TEST_ROOT"
}

BeforeEach 'setup'
AfterEach 'cleanup'

run_script() {
  PATH="$TEST_ROOT/bin:$PATH" bash "$SCRIPT"
}

It 'appends the system tool directories to the activation PATH'
When run bash -c "grep -F 'export PATH=\"\$PATH:/usr/sbin:/usr/bin:/sbin:/bin\"' '$SCRIPT'"
The status should be success
The output should include '/usr/bin'
End

It 'skips the install when libatomic1 is present'
export MOCK_STATUS='install ok installed'
When call run_script
The status should be success
The contents of file "$COMMAND_LOG" should eq ''
End

It 'installs libatomic1 through sudo when it is missing'
export MOCK_STATUS=''
When call run_script
The status should be success
The output should include 'Installing libatomic1'
The contents of file "$COMMAND_LOG" should include 'sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y -qq libatomic1'
The contents of file "$COMMAND_LOG" should include 'apt-get install -y -qq libatomic1'
End

It 'installs without sudo when run as root'
export MOCK_STATUS='' MOCK_UID=0
When call run_script
The status should be success
The output should include 'Installing libatomic1'
The contents of file "$COMMAND_LOG" should not include 'sudo'
The contents of file "$COMMAND_LOG" should include 'apt-get install -y -qq libatomic1'
End
End

Describe 'named-hosts/beskar/activate-sshd.sh'
SCRIPT="$PWD/named-hosts/beskar/activate-sshd.sh"

setup() {
  TEST_ROOT=$(mktemp -d)
  mkdir -p "$TEST_ROOT/bin" "$TEST_ROOT/sshd_config.d"
  COMMAND_LOG="$TEST_ROOT/commands.log"
  : >"$COMMAND_LOG"
  cat >"$TEST_ROOT/bin/id" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "${MOCK_UID:-0}"
EOF
  cat >"$TEST_ROOT/bin/sshd" <<'EOF'
#!/usr/bin/env bash
printf 'sshd %s\n' "$*" >>"$COMMAND_LOG"
exit "${MOCK_SSHD_STATUS:-0}"
EOF
  cat >"$TEST_ROOT/bin/systemctl" <<'EOF'
#!/usr/bin/env bash
printf 'systemctl %s\n' "$*" >>"$COMMAND_LOG"
exit "${MOCK_SYSTEMCTL_STATUS:-0}"
EOF
  chmod +x "$TEST_ROOT"/bin/*
  export COMMAND_LOG SSHD_CONFIG_DIR="$TEST_ROOT/sshd_config.d"
}

cleanup() {
  rm -rf "$TEST_ROOT"
}

BeforeEach 'setup'
AfterEach 'cleanup'

run_script() {
  PATH="$TEST_ROOT/bin:$PATH" bash "$SCRIPT"
}

It 'replaces the Kyber drop-in with a key-only root policy'
printf 'PermitRootLogin no\n' >"$SSHD_CONFIG_DIR/99-kyber-hardening.conf"
When call run_script
The status should be success
The output should include 'sshd hardening applied'
The path "$SSHD_CONFIG_DIR/99-kyber-hardening.conf" should not be exist
The contents of file "$SSHD_CONFIG_DIR/99-beskar-hardening.conf" should include 'PermitRootLogin prohibit-password'
The contents of file "$SSHD_CONFIG_DIR/99-beskar-hardening.conf" should include 'AllowUsers root ubuntu'
The contents of file "$SSHD_CONFIG_DIR/99-beskar-hardening.conf" should include 'PasswordAuthentication no'
The contents of file "$COMMAND_LOG" should include 'systemctl reload ssh'
End

It 'restores the previous drop-in when sshd -t fails'
printf 'PermitRootLogin no\n' >"$SSHD_CONFIG_DIR/99-kyber-hardening.conf"
export MOCK_SSHD_STATUS=1
When call run_script
The status should be failure
The stderr should include 'restoring the previous drop-in'
The output should include 'Installing'
The path "$SSHD_CONFIG_DIR/99-beskar-hardening.conf" should not be exist
The contents of file "$SSHD_CONFIG_DIR/99-kyber-hardening.conf" should eq 'PermitRootLogin no'
End

It 'keeps an existing Beskar drop-in when sshd -t fails'
printf 'old beskar\n' >"$SSHD_CONFIG_DIR/99-beskar-hardening.conf"
printf 'PermitRootLogin no\n' >"$SSHD_CONFIG_DIR/99-kyber-hardening.conf"
export MOCK_SSHD_STATUS=1
When call run_script
The status should be failure
The stderr should include 'restoring the previous drop-ins'
The output should include 'Installing'
The contents of file "$SSHD_CONFIG_DIR/99-beskar-hardening.conf" should eq 'old beskar'
The contents of file "$SSHD_CONFIG_DIR/99-kyber-hardening.conf" should eq 'PermitRootLogin no'
End

It 'fails and restores when sshd cannot reload'
printf 'PermitRootLogin no\n' >"$SSHD_CONFIG_DIR/99-kyber-hardening.conf"
export MOCK_SYSTEMCTL_STATUS=1
When call run_script
The status should be failure
The stderr should include 'Reloading sshd failed'
The output should include 'Installing'
The path "$SSHD_CONFIG_DIR/99-beskar-hardening.conf" should not be exist
The contents of file "$SSHD_CONFIG_DIR/99-kyber-hardening.conf" should eq 'PermitRootLogin no'
End

It 'does nothing when already up to date'
PATH="$TEST_ROOT/bin:$PATH" bash "$SCRIPT" >/dev/null
: >"$COMMAND_LOG"
When call run_script
The status should be success
The contents of file "$COMMAND_LOG" should eq ''
End

It 'refuses to run without root even when up to date'
PATH="$TEST_ROOT/bin:$PATH" bash "$SCRIPT" >/dev/null
export MOCK_UID=1000
When call run_script
The status should be failure
The stderr should include 'requires root'
End
End
