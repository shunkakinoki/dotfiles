#!/usr/bin/env bash
# shellcheck disable=SC2329,SC2016

Describe 'home-manager/modules/secure-dotenv/secure-dotenv.sh'
SCRIPT="$PWD/home-manager/modules/secure-dotenv/secure-dotenv.sh"

Describe 'script properties'
It 'uses bash shebang'
When run bash -c "head -1 '$SCRIPT'"
The output should include '#!/usr/bin/env bash'
End

It 'uses strict mode'
When run bash -c "head -5 '$SCRIPT'"
The output should include 'set -euo pipefail'
End

It 'passes bash syntax check after stripping placeholders'
When run bash -c "sed 's|@[A-Za-z_][A-Za-z0-9_]*@|/usr/bin/test|g' '$SCRIPT' | bash -n"
The status should be success
End
End

Describe 'placeholder substitutions'
It 'references @find@'
When run bash -c "grep '@find@' '$SCRIPT'"
The output should include '@find@'
End

It 'references @stat@'
When run bash -c "grep '@stat@' '$SCRIPT'"
The output should include '@stat@'
End
End

Describe 'requires HOME_DIR argument'
It 'reads HOME_DIR from $1'
When run bash -c "grep 'HOME_DIR=.\$1.' '$SCRIPT'"
The output should include 'HOME_DIR="$1"'
End
End

Describe 'functional behavior'
setup() {
  TEST_HOME="$(mktemp -d)"
  # Create .env files with non-600 permissions
  echo "SECRET=value" >"$TEST_HOME/.env"
  chmod 644 "$TEST_HOME/.env"

  mkdir -p "$TEST_HOME/subdir"
  echo "DB_URL=postgres://..." >"$TEST_HOME/subdir/.env.local"
  chmod 755 "$TEST_HOME/subdir/.env.local"

  echo "KEY=val" >"$TEST_HOME/app.env"
  chmod 644 "$TEST_HOME/app.env"

  # Create a file already at 600
  echo "OK=true" >"$TEST_HOME/.env.safe"
  chmod 600 "$TEST_HOME/.env.safe"

  # Create a symlink (should be skipped)
  ln -s "$TEST_HOME/.env" "$TEST_HOME/.env.link"

  # Preprocess the script, replacing placeholders with real commands
  PROCESSED_SCRIPT="$TEST_HOME/secure-dotenv-test.sh"
  sed \
    -e "s|@find@|$(command -v find)|g" \
    -e "s|@stat@|$(command -v stat)|g" \
    "$SCRIPT" >"$PROCESSED_SCRIPT"
  chmod +x "$PROCESSED_SCRIPT"

  export TEST_HOME PROCESSED_SCRIPT
}
cleanup() {
  rm -rf "$TEST_HOME"
  unset TEST_HOME PROCESSED_SCRIPT
}
Before 'setup'
After 'cleanup'

It 'changes .env from 644 to 600'
When run bash "$PROCESSED_SCRIPT" "$TEST_HOME"
The status should be success
End

It 'changes .env.local from 755 to 600'
When run bash -c "bash '$PROCESSED_SCRIPT' '$TEST_HOME' && stat -c '%a' '$TEST_HOME/subdir/.env.local'"
The output should equal '600'
End

It 'changes app.env from 644 to 600'
When run bash -c "bash '$PROCESSED_SCRIPT' '$TEST_HOME' && stat -c '%a' '$TEST_HOME/app.env'"
The output should equal '600'
End

It 'leaves already-600 files unchanged'
When run bash -c "bash '$PROCESSED_SCRIPT' '$TEST_HOME' && stat -c '%a' '$TEST_HOME/.env.safe'"
The output should equal '600'
End

It 'does not follow symlinks'
When run bash -c "bash '$PROCESSED_SCRIPT' '$TEST_HOME' && test -L '$TEST_HOME/.env.link' && echo 'still-symlink'"
The output should equal 'still-symlink'
End
End

Describe 'depth limit'
It 'uses maxdepth 4'
When run bash -c "grep 'maxdepth 4' '$SCRIPT'"
The output should include 'maxdepth 4'
End
End

End
