#!/usr/bin/env bash
# shellcheck disable=SC2016,SC2329

Describe 'home-manager/services/dolt/start.sh'
SCRIPT="$PWD/home-manager/services/dolt/start.sh"

Describe 'script properties'
It 'uses bash shebang'
When run bash -c "head -1 '$SCRIPT'"
The output should include '#!/usr/bin/env bash'
End

It 'uses strict mode'
When run bash -c "grep 'set -euo pipefail' '$SCRIPT'"
The output should include 'set -euo pipefail'
End

It 'passes bash syntax check after stripping placeholders'
When run bash -c "sed 's|@[A-Za-z_][A-Za-z0-9_]*@|/usr|g' '$SCRIPT' | bash -n"
The status should be success
End
End

Describe 'placeholder substitutions'
It 'references @beadsDir@'
When run bash -c "grep '@beadsDir@' '$SCRIPT'"
The output should include '@beadsDir@'
End

It 'references @legacyBeadsDir@'
When run bash -c "grep '@legacyBeadsDir@' '$SCRIPT'"
The output should include '@legacyBeadsDir@'
End

It 'references @dolt@'
When run bash -c "grep '@dolt@' '$SCRIPT'"
The output should include '@dolt@'
End
End

Describe 'dolt migration behavior'
setup_migration() {
  TEST_ROOT=$(mktemp -d)
  LEGACY_DIR="$TEST_ROOT/legacy"
  SHARED_DIR="$TEST_ROOT/shared/dolt"
  FAKE_DOLT="$TEST_ROOT/fake-dolt"
  RENDERED_SCRIPT="$TEST_ROOT/start.sh"
  mkdir -p "$LEGACY_DIR" "$SHARED_DIR" "$FAKE_DOLT/bin"
  printf '%s\n' '#!/usr/bin/env bash' 'exit 0' >"$FAKE_DOLT/bin/dolt"
  chmod +x "$FAKE_DOLT/bin/dolt"
  sed \
    -e "s|@legacyBeadsDir@|$LEGACY_DIR|g" \
    -e "s|@beadsDir@|$SHARED_DIR|g" \
    -e "s|@dolt@|$FAKE_DOLT|g" \
    "$SCRIPT" >"$RENDERED_SCRIPT"
}

cleanup_migration() {
  rm -rf "$TEST_ROOT"
}

Before 'setup_migration'
After 'cleanup_migration'

It 'moves a legacy database into the shared-server root'
mkdir -p "$LEGACY_DIR/beads/.dolt"
When run bash "$RENDERED_SCRIPT"
The status should be success
The path "$SHARED_DIR/beads/.dolt" should be directory
The path "$LEGACY_DIR/beads" should not be exist
End

It 'does not overwrite an existing shared-server database'
mkdir -p "$LEGACY_DIR/df/.dolt" "$SHARED_DIR/df/.dolt"
touch "$LEGACY_DIR/df/.dolt/legacy-marker"
When run bash "$RENDERED_SCRIPT"
The status should be success
The path "$LEGACY_DIR/df/.dolt/legacy-marker" should be file
The path "$SHARED_DIR/df/.dolt" should be directory
End

It 'maps the old dolt database name to df during legacy-root migration'
mkdir -p "$LEGACY_DIR/dolt/.dolt"
When run bash "$RENDERED_SCRIPT"
The status should be success
The path "$SHARED_DIR/df/.dolt" should be directory
The path "$SHARED_DIR/dolt" should not be exist
End

It 'does not rename a legitimate dolt database in the shared-server root'
mkdir -p "$SHARED_DIR/dolt/.dolt"
When run bash "$RENDERED_SCRIPT"
The status should be success
The path "$SHARED_DIR/dolt/.dolt" should be directory
The path "$SHARED_DIR/df" should not be exist
End

It 'atomically adopts a staged df database and retains the old one'
mkdir -p "$SHARED_DIR/df/.dolt" "$SHARED_DIR-incoming/df/.dolt"
touch "$SHARED_DIR/df/.dolt/old-marker"
touch "$SHARED_DIR-incoming/df/.dolt/new-marker"
When run bash "$RENDERED_SCRIPT"
The status should be success
The path "$SHARED_DIR/df/.dolt/new-marker" should be file
The path "$SHARED_DIR-retired/df/.dolt/old-marker" should be file
The path "$SHARED_DIR-incoming/df" should not be exist
End

It 'refuses to overwrite a retained df database during cutover'
mkdir -p "$SHARED_DIR/df/.dolt" "$SHARED_DIR-incoming/df/.dolt" "$SHARED_DIR-retired/df/.dolt"
When run bash "$RENDERED_SCRIPT"
The status should be failure
The stderr should include 'Refusing Dolt cutover'
The path "$SHARED_DIR-incoming/df/.dolt" should be directory
End
End

Describe 'sql-server invocation'
It 'defaults the listen host to localhost'
When run grep -F 'BEADS_DOLT_LISTEN_HOST:-127.0.0.1' "$SCRIPT"
The output should include 'BEADS_DOLT_LISTEN_HOST:-127.0.0.1'
End

It 'passes the selected listen host to Dolt'
When run grep -F -- '-H "$listen_host"' "$SCRIPT"
The output should include '-H "$listen_host"'
End

It 'listens on port 3307'
When run bash -c "grep -- '-P 3307' '$SCRIPT'"
The output should include '-P 3307'
End

It 'points --data-dir at the beads directory'
When run bash -c "grep -- '--data-dir' '$SCRIPT'"
The output should include '--data-dir'
End
End

End

Describe 'home-manager/services/dolt/default.nix'
MODULE="$PWD/home-manager/services/dolt/default.nix"

It 'uses the canonical Beads shared-server directory'
When run grep -F 'sharedServerDir = "${homeDir}/.beads/shared-server";' "$MODULE"
The output should include 'sharedServerDir = "${homeDir}/.beads/shared-server";'
End

It 'serves databases from the shared-server dolt directory'
When run grep -F 'beadsDir = "${sharedServerDir}/dolt";' "$MODULE"
The output should include 'beadsDir = "${sharedServerDir}/dolt";'
End

It 'routes every client to its own local server'
When run bash -c "grep -F 'doltServerHost = \"127.0.0.1\";' '$MODULE' >/dev/null && grep -F 'BEADS_DOLT_SERVER_HOST = doltServerHost;' '$MODULE' >/dev/null && grep -F 'BEADS_DOLT_SERVER_USER = \"root\";' '$MODULE' >/dev/null && ! grep -F 'kyber.tail950b36.ts.net' '$MODULE' >/dev/null"
The status should be success
End
End
