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
