#!/usr/bin/env bash
# shellcheck disable=SC2016,SC2329

Describe 'home-manager/activation/atuin-login.sh'
SCRIPT="$PWD/home-manager/activation/atuin-login.sh"

setup() {
  TMP="$(mktemp -d)"
  touch "$TMP/identity" "$TMP/secret"
  cat >"$TMP/rage" <<'EOF'
#!/usr/bin/env bash
[ -z "${RAGE_FAIL:-}" ] || exit 1
printf '%b' "$RAGE_OUTPUT"
EOF
  cat >"$TMP/atuin" <<'EOF'
#!/usr/bin/env bash
printf '%s|%s|%s\n' "$*" "$ATUIN_PASSWORD" "$ATUIN_ENCRYPTION_KEY" >"$(dirname "$0")/called"
exit "${ATUIN_EXIT:-0}"
EOF
  chmod +x "$TMP/rage" "$TMP/atuin"
  export RAGE_OUTPUT='pass word\nkey words\n'
}
cleanup() { rm -rf "$TMP"; }
BeforeEach 'setup'
AfterEach 'cleanup'

run_login() {
  bash "$SCRIPT" "$TMP/secret" "$TMP/identity" "$TMP/rage" "$TMP/atuin" user "$TMP/session"
}

It 'logs in with the secret passed through the environment'
When call run_login
The status should be success
The output should include 'Logged in to Atuin as user'
The contents of file "$TMP/called" should equal 'login -u user|pass word|key words'
End

It 'leaves an existing session alone'
existing_session() {
  echo token >"$TMP/session"
  run_login
}
When call existing_session
The status should be success
The path "$TMP/called" should not be exist
End

It 'skips hosts that cannot decrypt the secret'
export RAGE_FAIL=1
When call run_login
The status should be success
The path "$TMP/called" should not be exist
End

It 'skips hosts without an identity key'
missing_identity() {
  bash "$SCRIPT" "$TMP/secret" "$TMP/missing" "$TMP/rage" "$TMP/atuin" user "$TMP/session"
}
When call missing_identity
The status should be success
The path "$TMP/called" should not be exist
End

It 'backs up an existing local key before logging in'
existing_key() {
  echo local-key >"$TMP/key"
  run_login
}
When call existing_key
The status should be success
The output should include 'Logged in'
The contents of file "$TMP/key.pre-login" should equal 'local-key'
End

It 'keeps an earlier key backup'
earlier_backup() {
  echo newer-key >"$TMP/key"
  echo first-key >"$TMP/key.pre-login"
  run_login
}
When call earlier_backup
The status should be success
The output should include 'Logged in'
The contents of file "$TMP/key.pre-login" should equal 'first-key'
End

It 'skips an incomplete secret'
export RAGE_OUTPUT='only-password\n'
When call run_login
The status should be success
The error should include 'incomplete'
The path "$TMP/called" should not be exist
End

It 'does not fail activation when login fails'
export ATUIN_EXIT=1
When call run_login
The status should be success
The error should include 'login failed'
End
End
