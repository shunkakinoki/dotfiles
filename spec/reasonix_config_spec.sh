#!/usr/bin/env bash
# shellcheck disable=SC2329,SC2016

Describe 'Reasonix CLIProxy config'
CONFIG="$PWD/config/reasonix/config.toml"
TEMPLATE="$PWD/config/reasonix/config.tpl.toml"
HYDRATE="$PWD/config/reasonix/hydrate.sh"

It 'routes the default model through remote CLIProxy'
When run bash -c "grep -E '^(default_model = \"cliproxy-deepseek-flash\"|base_url = \"https://cliproxy.shunkakinoki.com/v1\"|api_key_env = \"CLIPROXY_API_KEY\")$' '$CONFIG'"
The status should be success
The output should include 'default_model = "cliproxy-deepseek-flash"'
The output should include 'base_url = "https://cliproxy.shunkakinoki.com/v1"'
The output should include 'api_key_env = "CLIPROXY_API_KEY"'
End

It 'keeps the generated config aligned with its template'
When run bash -c "diff -u <(sed 's/__DEEPSEEK_FLASH__/deepseek-v4.1-flash/g' '$TEMPLATE') '$CONFIG'"
The status should be success
End

It 'passes bash syntax check after stripping placeholders'
When run bash -c "sed 's|@[A-Za-z_][A-Za-z0-9_]*@|/usr/bin/true|g' '$HYDRATE' | bash -n"
The status should be success
End

Describe 'hydrate behavior'
no_tomlq() { ! command -v tomlq >/dev/null 2>&1; }
Skip if 'tomlq is unavailable (activation substitutes pkgs.yq)' no_tomlq

setup() {
  TEST_HOME="$(mktemp -d)"
  RUNNER="$TEST_HOME/hydrate.sh"
  sed -e "s|@template@|$CONFIG|" -e "s|@tomlq@|$(command -v tomlq)|g" -e 's|@awk@|awk|g' "$HYDRATE" >"$RUNNER"
}
cleanup() {
  rm -rf "$TEST_HOME"
  unset TEST_HOME RUNNER
}
BeforeEach 'setup'
AfterEach 'cleanup'

hydrate() { env HOME="$TEST_HOME" CLIPROXY_API_KEY=test-key bash "$RUNNER"; }

seed_user_config() {
  mkdir -p "$TEST_HOME/.reasonix"
  cat >"$TEST_HOME/.reasonix/config.toml" <<'TOML'
default_model = "mine"   # user choice

[ui]
theme = "dark"

[[providers]]
name = "mine"
kind = "openai"
base_url = "http://localhost:1"
model = "local"
api_key_env = "MINE_KEY"

[[providers]]
name = "cliproxy-deepseek-flash"
kind = "openai"
base_url = "https://cliproxy.shunkakinoki.com/v1"
model = "stale"
api_key_env = "CLIPROXY_API_KEY"
TOML
}

It 'seeds config and mirrors the key when Reasonix has no state'
When call hydrate
The status should be success
The stderr should include 'Seeded Reasonix config'
The contents of file "$TEST_HOME/.reasonix/config.toml" should include 'deepseek-v4.1-flash'
The contents of file "$TEST_HOME/.reasonix/.env" should equal 'CLIPROXY_API_KEY=test-key'
End

It 'upserts the managed provider and keeps user settings'
check() {
  seed_user_config
  hydrate 2>/dev/null
  tomlq -c '[.default_model, .ui.theme, [.providers[] | [.name, .model]]]' "$TEST_HOME/.reasonix/config.toml"
}
When call check
The output should equal '["cliproxy-deepseek-flash","dark",[["mine","local"],["cliproxy-deepseek-flash","deepseek-v4.1-flash"]]]'
End

It 'leaves an already hydrated config untouched'
check() {
  seed_user_config
  hydrate 2>/dev/null
  before="$(cksum <"$TEST_HOME/.reasonix/config.toml")"
  hydrate
  [ "$before" = "$(cksum <"$TEST_HOME/.reasonix/config.toml")" ] && echo unchanged
}
When call check
The output should equal 'unchanged'
End

It 'keeps unrelated keys in the Reasonix .env'
check() {
  mkdir -p "$TEST_HOME/.reasonix"
  printf 'DEEPSEEK_API_KEY=keep\nCLIPROXY_API_KEY=old\n' >"$TEST_HOME/.reasonix/.env"
  hydrate 2>/dev/null
  cat "$TEST_HOME/.reasonix/.env"
}
When call check
The line 1 of output should equal 'DEEPSEEK_API_KEY=keep'
The line 2 of output should equal 'CLIPROXY_API_KEY=test-key'
End
End
End
