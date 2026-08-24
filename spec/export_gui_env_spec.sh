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

It 'does not contain a static GUI key allowlist'
When run bash -c "! grep -Eq '@keys@|guiEnvKeys|AMP_API_KEY|OPENCODE_API_KEY' '$SCRIPT' '$PWD/home-manager/modules/dotenv/default.nix'"
The status should be success
End
End

Describe 'functional behavior'
setup() {
  TEST_HOME="$(mktemp -d)"
  LAUNCHCTL_STUB="$TEST_HOME/launchctl"
  cat >"$LAUNCHCTL_STUB" <<'STUB'
#!/usr/bin/env bash
printf '%s %s value=<%s>\n' "$1" "$2" "$3" >>"${LAUNCHCTL_LOG}"
STUB
  chmod +x "$LAUNCHCTL_STUB"

  LAUNCHCTL_LOG="$TEST_HOME/launchctl.log"
  : >"$LAUNCHCTL_LOG"

  PROCESSED_SCRIPT="$TEST_HOME/export-gui-env-test.sh"
  sed \
    -e "s|@launchctl@|$LAUNCHCTL_STUB|g" \
    -e "s|@printer@|$PWD/home-manager/modules/dotenv/print-env-file.sh|g" \
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

It 'exports every valid assignment emitted by the shared parser'
When call run_with_env 'AMP_API_KEY=amp-value
OPENCODE_API_KEY=opencode-value
CLIPROXY_API_KEY=cliproxy-value'
The line 1 of output should equal 'setenv AMP_API_KEY value=<amp-value>'
The line 2 of output should equal 'setenv OPENCODE_API_KEY value=<opencode-value>'
The line 3 of output should equal 'setenv CLIPROXY_API_KEY value=<cliproxy-value>'
End

It 'exports keys outside the previous allowlist'
When call run_with_env 'ARBITRARY_GUI_VALUE=available'
The output should equal 'setenv ARBITRARY_GUI_VALUE value=<available>'
End

It 'preserves an explicitly empty value'
When call run_with_env 'EMPTY_GUI_VALUE='
The output should equal 'setenv EMPTY_GUI_VALUE value=<>'
End

It 'reports the exported key without printing its value'
When run bash -c "printf '%s\n' 'PRIVATE_GUI_VALUE=do-not-print' >'$TEST_HOME/env'; DOTFILES_ENV_FILE='$TEST_HOME/env' HOME='$TEST_HOME' bash '$PROCESSED_SCRIPT'"
The output should equal 'Exported PRIVATE_GUI_VALUE to the GUI session'
The output should not include 'do-not-print'
End

It 'still excludes invalid keys and comments through the shared parser'
When call run_with_env 'VALID_GUI_VALUE=yes
INVALID-GUI-VALUE=no
# COMMENTED_GUI_VALUE=no'
The output should equal 'setenv VALID_GUI_VALUE value=<yes>'
End

It 'succeeds when the env file is absent'
When run bash -c "DOTFILES_ENV_FILE='$TEST_HOME/missing' HOME='$TEST_HOME' bash '$PROCESSED_SCRIPT' 2>/dev/null"
The status should be success
End
End
End
