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
if [ "$1" = key ]; then
  cat "$(dirname "$0")/key"
  exit 0
fi
printf '%s|%s|%s\n' "$*" "$ATUIN_PASSWORD" "$ATUIN_ENCRYPTION_KEY" >"$(dirname "$0")/called"
exit "${ATUIN_EXIT:-0}"
EOF
  cat >"$TMP/timeout" <<'EOF'
#!/usr/bin/env bash
echo "$1" >"$(dirname "$0")/bound"
shift
exec "$@"
EOF
  cat >"$TMP/ssh-keygen" <<'EOF'
#!/usr/bin/env bash
[ -z "${KEY_HAS_PASSPHRASE:-}" ] || exit 255
EOF
  chmod +x "$TMP/rage" "$TMP/atuin" "$TMP/timeout" "$TMP/ssh-keygen"
  export RAGE_OUTPUT='pass word\nkey words\n'
}
cleanup() { rm -rf "$TMP"; }
BeforeEach 'setup'
AfterEach 'cleanup'

run_login() {
  bash "$SCRIPT" "$TMP/secret" "$TMP/identity" "$TMP/rage" "$TMP/atuin" "$TMP/timeout" "$TMP/ssh-keygen" user "$TMP"
}

It 'logs in with the secret passed through the environment'
When call run_login
The status should be success
The contents of file "$TMP/called" should equal 'login -u user|pass word|key words'
End

It 'bounds the login with a timeout'
When call run_login
The status should be success
The contents of file "$TMP/bound" should equal '60'
End

It 'ignores a stale session file and leaves the decision to atuin'
stale_session() {
  echo token >"$TMP/session"
  run_login
}
When call stale_session
The status should be success
The path "$TMP/called" should be exist
End

It 'logs in when the local key matches the secret'
matching_key() {
  echo 'key words' >"$TMP/key"
  run_login
}
When call matching_key
The status should be success
The path "$TMP/called" should be exist
End

It 'skips login when the local key differs from the secret'
different_key() {
  echo 'local key' >"$TMP/key"
  run_login
}
When call different_key
The status should be success
The error should include 'differs'
The path "$TMP/called" should not be exist
The contents of file "$TMP/key" should equal 'local key'
End

It 'skips hosts that cannot decrypt the secret'
export RAGE_FAIL=1
When call run_login
The status should be success
The path "$TMP/called" should not be exist
End

It 'skips hosts without an identity key'
missing_identity() {
  bash "$SCRIPT" "$TMP/secret" "$TMP/missing" "$TMP/rage" "$TMP/atuin" "$TMP/timeout" "$TMP/ssh-keygen" user "$TMP"
}
When call missing_identity
The status should be success
The path "$TMP/called" should not be exist
End

It 'skips a passphrase-protected identity without calling rage'
export KEY_HAS_PASSPHRASE=1
export RAGE_OUTPUT='rage was called\nkey words\n'
When call run_login
The status should be success
The path "$TMP/called" should not be exist
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
