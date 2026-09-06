#!/usr/bin/env bash
# shellcheck disable=SC2329

Describe 'Provisioning a missing Beads database'
setup() {
  TEST_ROOT=$(mktemp -d)
  REPO_DIR="$TEST_ROOT/repo"
  DOLT_DIR="$TEST_ROOT/dolt"
  JQ_DIR="$TEST_ROOT/jq"
  RENDERED_SCRIPT="$TEST_ROOT/ensure-database.sh"
  export DATABASE_STATE="$TEST_ROOT/database-state"
  export DATABASE_COMMANDS="$TEST_ROOT/commands"
  mkdir -p "$REPO_DIR/.beads" "$DOLT_DIR/bin" "$JQ_DIR/bin"
  printf '{"dolt_database":"beads_fixture"}\n' >"$REPO_DIR/.beads/metadata.json"
  touch "$DATABASE_COMMANDS"
  ln -s "$(command -v jq)" "$JQ_DIR/bin/jq"
  cat >"$DOLT_DIR/bin/dolt" <<'EOF'
#!/usr/bin/env bash
query="${!#}"
printf '%s\n' "$query" >>"$DATABASE_COMMANDS"
case "$query" in
  'SHOW DATABASES')
    if [ "${FAKE_INVALID_INVENTORY:-0}" = 1 ]; then printf '{"rows":null}\n'; exit 0; fi
    if [ "${FAKE_SERVER_UNAVAILABLE:-0}" = 1 ]; then exit 42; fi
    if [ -f "$DATABASE_STATE" ]; then
      printf '{"rows":[{"Database":"beads_fixture"}]}\n'
    else
      printf '{"rows":[{"Database":"mysql"}]}\n'
    fi
    ;;
  'CALL DOLT_CLONE('* )
    if [ "${FAKE_CLONE_FAILURE:-0}" = 1 ]; then exit 43; fi
    touch "$DATABASE_STATE"
    printf '{"rows":[{"status":0}]}\n'
    ;;
  *) exit 44 ;;
esac
EOF
  chmod +x "$DOLT_DIR/bin/dolt"
  sed -e "s|@dolt@|$DOLT_DIR|g" -e "s|@jq@|$JQ_DIR|g" home-manager/services/dolt/ensure-database.sh >"$RENDERED_SCRIPT"
}

cleanup() { rm -rf "$TEST_ROOT"; }
run_twice() {
  bash "$RENDERED_SCRIPT" "$REPO_DIR" 'https://example.invalid/fixture'
  bash "$RENDERED_SCRIPT" "$REPO_DIR" 'https://example.invalid/fixture'
  grep -c 'CALL DOLT_CLONE' "$DATABASE_COMMANDS"
}
Before 'setup'
After 'cleanup'

It 'clones the configured database once and leaves it intact on rerun'
When call run_twice
The status should be success
The output should eq "Provisioning missing database from its configured remote
1"
The file "$DATABASE_STATE" should be exist
End

It 'does not reinitialize an existing database'
touch "$DATABASE_STATE"
When run bash "$RENDERED_SCRIPT" "$REPO_DIR" 'https://example.invalid/fixture'
The status should be success
The contents of file "$DATABASE_COMMANDS" should eq 'SHOW DATABASES'
End

It 'does not mistake an unreachable server for a missing database'
When run env FAKE_SERVER_UNAVAILABLE=1 bash "$RENDERED_SCRIPT" "$REPO_DIR" 'https://example.invalid/fixture'
The status should equal 42
The stderr should include 'Dolt server database discovery failed'
The file "$DATABASE_STATE" should not be exist
The contents of file "$DATABASE_COMMANDS" should eq 'SHOW DATABASES'
End

It 'preserves a repository-local database for an explicit cutover'
mkdir -p "$REPO_DIR/.beads/dolt/beads_fixture/.dolt/noms"
touch "$REPO_DIR/.beads/dolt/beads_fixture/.dolt/noms/manifest"
When run bash "$RENDERED_SCRIPT" "$REPO_DIR" 'https://example.invalid/fixture'
The status should equal 1
The stderr should include 'Preserved local database'
The file "$DATABASE_STATE" should not be exist
The contents of file "$DATABASE_COMMANDS" should eq 'SHOW DATABASES'
End

It 'propagates clone failure without claiming provisioning succeeded'
When run env FAKE_CLONE_FAILURE=1 bash "$RENDERED_SCRIPT" "$REPO_DIR" 'https://example.invalid/fixture'
The status should equal 43
The stderr should include 'Dolt database clone failed'
The output should include 'Provisioning missing database'
The file "$DATABASE_STATE" should not be exist
End

It 'rejects SQL syntax in configured database names'
printf '{"dolt_database":"fixture; DROP DATABASE other"}\n' >"$REPO_DIR/.beads/metadata.json"
When run bash "$RENDERED_SCRIPT" "$REPO_DIR" 'https://example.invalid/fixture'
The status should equal 1
The stderr should include 'Invalid configured Dolt database name'
The file "$DATABASE_COMMANDS" should be empty file
End

It 'rejects SQL delimiters in a remote URL'
When run bash "$RENDERED_SCRIPT" "$REPO_DIR" "https://example.invalid/fixture'"
The status should equal 1
The stderr should include 'Invalid database remote URL'
The file "$DATABASE_STATE" should not be exist
End
It 'rejects credential-bearing remote URLs without logging them'
When run bash "$RENDERED_SCRIPT" "$REPO_DIR" 'https://user:secret@example.invalid/fixture'
The status should equal 1
The stderr should eq 'Invalid database remote URL'
The file "$DATABASE_STATE" should not be exist
End

It 'does not expose the checkout path when metadata is missing'
rm -f "$REPO_DIR/.beads/metadata.json"
When run bash "$RENDERED_SCRIPT" "$REPO_DIR" 'https://example.invalid/fixture'
The status should equal 1
The stderr should eq 'Cannot read configured Dolt database name'
The file "$DATABASE_COMMANDS" should be empty file
End
It 'does not clone when the server returns an invalid database inventory'
When run env FAKE_INVALID_INVENTORY=1 bash "$RENDERED_SCRIPT" "$REPO_DIR" 'https://example.invalid/fixture'
The status should equal 1
The stderr should eq 'Dolt server returned an invalid database inventory'
The contents of file "$DATABASE_COMMANDS" should eq 'SHOW DATABASES'
The file "$DATABASE_STATE" should not be exist
End
End
