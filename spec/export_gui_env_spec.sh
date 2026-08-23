#!/usr/bin/env bash
# shellcheck disable=SC2329,SC2016

Describe 'home-manager/modules/dotenv/export-gui-env.sh'
SCRIPT="$PWD/home-manager/modules/dotenv/export-gui-env.sh"

Describe 'script properties'
It 'uses bash shebang'
When run bash -c "head -1 '$SCRIPT'"
The output should include '#!/usr/bin/env bash'
End

It 'uses strict mode'
When run bash -c "head -8 '$SCRIPT'"
The output should include 'set -euo pipefail'
End

It 'passes bash syntax check after stripping placeholders'
When run bash -c "sed 's|@[A-Za-z_][A-Za-z0-9_]*@|/usr/bin/true|g' '$SCRIPT' | bash -n"
The status should be success
End

It 'references @launchctl@'
When run bash -c "grep '@launchctl@' '$SCRIPT'"
The output should include '@launchctl@'
End

It 'references @printer@'
When run bash -c "grep '@printer@' '$SCRIPT'"
The output should include '@printer@'
End

It 'references @keys@'
When run bash -c "grep '@keys@' '$SCRIPT'"
The output should include '@keys@'
End
End

Describe 'functional behavior'
setup() {
  TEST_HOME="$(mktemp -d)"
  LAUNCHCTL_STUB="$TEST_HOME/launchctl"
  cat >"$LAUNCHCTL_STUB" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"${LAUNCHCTL_LOG}"
STUB
  chmod +x "$LAUNCHCTL_STUB"

  LAUNCHCTL_LOG="$TEST_HOME/launchctl.log"
  : >"$LAUNCHCTL_LOG"

  PROCESSED_SCRIPT="$TEST_HOME/export-gui-env-test.sh"
  sed \
    -e "s|@launchctl@|$LAUNCHCTL_STUB|g" \
    -e "s|@printer@|$PWD/home-manager/modules/dotenv/print-env-file.sh|g" \
    -e "s|@keys@|AMP_API_KEY OPENCODE_API_KEY|g" \
    "$SCRIPT" >"$PROCESSED_SCRIPT"

  export TEST_HOME LAUNCHCTL_STUB LAUNCHCTL_LOG PROCESSED_SCRIPT
}
cleanup() {
  rm -rf "$TEST_HOME"
  unset TEST_HOME LAUNCHCTL_STUB LAUNCHCTL_LOG PROCESSED_SCRIPT
}
Before 'setup'
After 'cleanup'

run_with_env() {
  printf '%s\n' "$1" >"$TEST_HOME/env"
  DOTFILES_ENV_FILE="$TEST_HOME/env" HOME="$TEST_HOME" bash "$PROCESSED_SCRIPT" >/dev/null 2>&1
  cat "$LAUNCHCTL_LOG"
}

It 'exports both allowlisted keys'
When call run_with_env 'AMP_API_KEY=amp-value
OPENCODE_API_KEY=opencode-value'
The line 1 of output should equal 'setenv AMP_API_KEY amp-value'
The line 2 of output should equal 'setenv OPENCODE_API_KEY opencode-value'
End

It 'skips keys missing from the env file'
When call run_with_env 'AMP_API_KEY=amp-value'
The output should equal 'setenv AMP_API_KEY amp-value'
End

It 'never exports keys outside the allowlist'
When call run_with_env 'CLIPROXY_API_KEY=secret'
The output should equal ''
End

It 'warns about a missing key'
When run bash -c "printf 'AMP_API_KEY=amp-value\n' >'$TEST_HOME/env'; DOTFILES_ENV_FILE='$TEST_HOME/env' HOME='$TEST_HOME' bash '$PROCESSED_SCRIPT' 2>&1 >/dev/null"
The output should include 'OPENCODE_API_KEY is unset'
End

It 'succeeds when the env file is absent'
When run bash -c "DOTFILES_ENV_FILE='$TEST_HOME/missing' HOME='$TEST_HOME' bash '$PROCESSED_SCRIPT' 2>/dev/null"
The status should be success
End
End
End
