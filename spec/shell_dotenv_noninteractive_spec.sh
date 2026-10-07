#!/usr/bin/env bash
# shellcheck disable=SC2329,SC2016

Describe 'non-interactive bash and zsh load .env'
BASH_ENV_FILE="$PWD/home-manager/programs/bash/bash_env.sh"
ZSH_CONFIG="$PWD/home-manager/programs/zsh/default.nix"
LOADER="$PWD/home-manager/modules/dotenv/load-env-file.sh"
PRINTER="$PWD/home-manager/modules/dotenv/print-env-file.sh"

setup() {
  TEST_HOME="$(mktemp -d)"
  mkdir -p "$TEST_HOME/.config/shell" "$TEST_HOME/dotfiles"
  cp "$LOADER" "$TEST_HOME/.config/shell/load-env-file.sh"
  cp "$PRINTER" "$TEST_HOME/.config/shell/print-env-file.sh"
  printf '%s\n' 'CLIPROXY_API_KEY=from-dotenv' >"$TEST_HOME/dotfiles/.env"
  BASH_BIN="$(command -v bash)"
  export TEST_HOME BASH_BIN
}
cleanup() {
  rm -rf "$TEST_HOME"
  unset TEST_HOME BASH_BIN
}
Before 'setup'
After 'cleanup'

run_bash_env() {
  env -i HOME="$TEST_HOME" PATH="$PATH" BASH_ENV="$BASH_ENV_FILE" "$BASH_BIN" -c "$1"
}

Describe 'bash via BASH_ENV'
It 'exports .env keys to plain bash -c'
When call run_bash_env 'printf "%s" "${CLIPROXY_API_KEY:-<unset>}"'
The output should equal 'from-dotenv'
End

It 'does not reload .env in nested bash, keeping per-command overrides'
When call run_bash_env 'CLIPROXY_API_KEY=override bash -c "printf %s \"\$CLIPROXY_API_KEY\""'
The output should equal 'override'
End

It 'succeeds when the loader is absent from the start'
setup_missing() { rm "$TEST_HOME/.config/shell/load-env-file.sh"; }
BeforeCall 'setup_missing'
When call run_bash_env 'printf "%s" "${CLIPROXY_API_KEY:-<unset>}"'
The status should be success
The output should equal '<unset>'
End
End

Describe 'zsh loader placement'
It 'loads .env from envExtra (.zshenv) before initContent'
When run bash -c "awk '/envExtra = /{env=NR} /initContent = /{init=NR} /_hm_load_env_file\$/{n++; load=NR} END{ if (n == 1 && env < load && load < init) print \"ok\"; else print \"bad env=\" env \" load=\" load \" init=\" init \" n=\" n }' '$ZSH_CONFIG'"
The output should equal 'ok'
End
End
End
