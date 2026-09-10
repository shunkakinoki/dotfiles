# shellcheck shell=bash disable=SC2016
Describe 'Herdr server environment'
SCRIPT="$PWD/home-manager/services/herdr/start.sh"
PACKAGE_CONFIG="$PWD/home-manager/packages/default.nix"
SERVICE_CONFIG="$PWD/home-manager/services/herdr/default.nix"
HOMEBREW_CONFIG="$PWD/nix-darwin/config/homebrew.nix"

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

Describe 'Herdr package ownership'
It 'keeps Herdr in the Nix Home Manager package set'
When run grep -Fx '  pkgs.llm-agents.herdr' "$PACKAGE_CONFIG"
The output should include '  pkgs.llm-agents.herdr'
End

It 'does not declare Herdr as a Homebrew formula'
When run grep -Fx '      "herdr"' "$HOMEBREW_CONFIG"
The status should not be success
End

It 'launches the Nix-backed Herdr package on Darwin'
When run grep -F '"${pkgs.llm-agents.herdr}/bin/herdr"' "$SERVICE_CONFIG"
The output should include '"${pkgs.llm-agents.herdr}/bin/herdr"'
End
End
End
