#!/usr/bin/env bash
# shellcheck disable=SC2329,SC2016

Describe 'home-manager/services/bwrap-apparmor/activate.sh'
SCRIPT="$PWD/home-manager/services/bwrap-apparmor/activate.sh"

setup() {
  BWRAP_TEST_ROOT="$(mktemp -d)"
  export BWRAP_APPARMOR_DIR="$BWRAP_TEST_ROOT/apparmor.d"
  export BWRAP_APPARMOR_PARSER="$BWRAP_TEST_ROOT/apparmor_parser"
  export MOCK_LOG="$BWRAP_TEST_ROOT/log"
  mkdir -p "$BWRAP_APPARMOR_DIR"
  cat >"$BWRAP_APPARMOR_PARSER" <<'MOCK'
#!/usr/bin/env bash
printf 'parser %s\n' "$*" >>"$MOCK_LOG"
MOCK
  chmod +x "$BWRAP_APPARMOR_PARSER"
}

cleanup() {
  rm -rf "$BWRAP_TEST_ROOT"
  unset BWRAP_TEST_ROOT BWRAP_APPARMOR_DIR BWRAP_APPARMOR_PARSER MOCK_LOG
}

BeforeEach 'setup'
AfterEach 'cleanup'

run_as_root() {
  id() { echo 0; }
  export -f id
  bash "$SCRIPT"
}

It 'grants the Nix store bwrap unconfined user namespaces and loads it'
When call run_as_root
The status should be success
The contents of file "$BWRAP_APPARMOR_DIR/nix-bwrap" should include 'profile nix-bwrap /nix/store/*-bubblewrap-*/bin/bwrap flags=(unconfined)'
The contents of file "$BWRAP_APPARMOR_DIR/nix-bwrap" should include 'userns,'
The contents of file "$MOCK_LOG" should equal "parser -r $BWRAP_APPARMOR_DIR/nix-bwrap"
End

It 'leaves an unchanged profile loaded without reloading'
run_twice() {
  run_as_root
  rm -f "$MOCK_LOG"
  run_as_root
}
When call run_twice
The status should be success
The path "$MOCK_LOG" should not be exist
End

It 'skips hosts without AppArmor'
rmdir "$BWRAP_APPARMOR_DIR"
When call run_as_root
The status should be success
The path "$BWRAP_APPARMOR_DIR/nix-bwrap" should not be exist
End
End
