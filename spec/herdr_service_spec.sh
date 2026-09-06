# shellcheck shell=bash
Describe 'Herdr server environment'
SCRIPT="$PWD/home-manager/services/herdr/start.sh"

setup() {
  TEMP_HOME=$(mktemp -d)
  mkdir -p "$TEMP_HOME/dotfiles" "$TEMP_HOME/.config/shell"
  cp -f home-manager/modules/dotenv/load-env-file.sh home-manager/modules/dotenv/print-env-file.sh "$TEMP_HOME/.config/shell/"
  cat >"$TEMP_HOME/dotfiles/.env" <<'ENV'
HERDR_TEST_VALUE="value with spaces"
HERDR_TEST_LITERAL=$(touch should-not-exist)
ENV
  cat >"$TEMP_HOME/herdr" <<'CLI'
#!/usr/bin/env bash
printf '%s\n' "$HERDR_TEST_VALUE" "$HERDR_TEST_LITERAL" "$*"
CLI
  chmod +x "$TEMP_HOME/herdr"
}

cleanup() {
  rm -rf "$TEMP_HOME"
}

Before 'setup'
After 'cleanup'

It 'loads values through the shared parser without evaluating shell expressions'
When run env -u DOTFILES_ENV_FILE -u HM_PRINT_ENV_FILE HOME="$TEMP_HOME" bash "$SCRIPT" "$TEMP_HOME/herdr"
The status should be success
The line 1 of output should equal 'value with spaces'
# shellcheck disable=SC2016
The line 2 of output should equal '$(touch should-not-exist)'
The line 3 of output should equal 'server'
End
End
