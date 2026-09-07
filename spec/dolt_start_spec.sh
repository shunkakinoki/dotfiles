#!/usr/bin/env bash
# shellcheck disable=SC2329
Describe 'authoritative Dolt startup'
  setup() {
    TEST_ROOT=$(mktemp -d)
    mkdir -p "$TEST_ROOT/fake/bin"
    printf '%s\n' '#!/usr/bin/env bash' 'printf "%s\n" "$@"' >"$TEST_ROOT/fake/bin/dolt"
    chmod +x "$TEST_ROOT/fake/bin/dolt"
    sed -e "s|@beadsDir@|$TEST_ROOT/data|g" -e "s|@dolt@|$TEST_ROOT/fake|g" home-manager/services/dolt/start.sh >"$TEST_ROOT/start.sh"
  }
  cleanup() { rm -rf "$TEST_ROOT"; }
  Before setup
  After cleanup
  It 'refuses to start an empty authority'
    When run bash "$TEST_ROOT/start.sh"
    The status should be failure
    The stderr should include 'data directory is missing'
    The path "$TEST_ROOT/data" should not be exist
  End
  It 'serves existing data without adopting preserved replicas'
    mkdir -p "$TEST_ROOT/data/df/.dolt" "$TEST_ROOT/data-incoming/df/.dolt"
    touch "$TEST_ROOT/data-incoming/df/.dolt/witness"
    When run bash "$TEST_ROOT/start.sh"
    The status should be success
    The output should include 'sql-server'
    The output should include '3307'
    The output should include "$TEST_ROOT/data"
    The output should not include 'remotesapi'
    The path "$TEST_ROOT/data-incoming/df/.dolt/witness" should be file
    The path "$TEST_ROOT/data/df/.dolt/witness" should not be exist
  End
End
