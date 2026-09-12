#!/usr/bin/env bash
# shellcheck disable=SC2016,SC2329
Describe 'UV global tool exclusions'
SCRIPT="$PWD/home-manager/modules/uv-globals/install-uv-globals.sh"

setup() {
  TEST_HOME=$(mktemp -d)
  mkdir -p "$TEST_HOME/bin" "$TEST_HOME/dotfiles" "$TEST_HOME/.local/bin" "$TEST_HOME/.agentsview"
  touch "$TEST_HOME/dotfiles/pyproject.toml"
  printf 'preserved archive\n' >"$TEST_HOME/.agentsview/sessions.db"
  printf 'old wrapper\n' >"$TEST_HOME/.local/bin/python3-agentsview"
  CALLS="$TEST_HOME/calls"
  export CALLS
  cat >"$TEST_HOME/bin/uv" <<'SCRIPT'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$CALLS"
case "$1 $2" in
  'tool list') printf '%s\n' "$INSTALLED_CONTENT"; exit "${LIST_STATUS:-0}" ;;
  'tool uninstall') exit "${UNINSTALL_STATUS:-0}" ;;
esac
SCRIPT
  cat >"$TEST_HOME/bin/timeout" <<'SCRIPT'
#!/usr/bin/env bash
exit "${NETWORK_STATUS:-0}"
SCRIPT
  cat >"$TEST_HOME/bin/tomlq" <<'SCRIPT'
#!/usr/bin/env bash
case "$2" in
  *requires-python*) printf '>=3.13\n' ;;
  *dependency-groups*) printf 'agentsview>=0.42.0\nother-tool>=1.0\n' ;;
esac
SCRIPT
  cat >"$TEST_HOME/bin/systemctl" <<'SCRIPT'
#!/usr/bin/env bash
printf 'starting\n'
SCRIPT
  chmod +x "$TEST_HOME/bin/"*
  export INSTALLED_CONTENT='agentsview v0.42.0'
}
cleanup() { rm -rf "$TEST_HOME"; }
Before 'setup'
After 'cleanup'

run_installer() {
  env HOME="$TEST_HOME" PATH="$TEST_HOME/bin:$PATH" \
    UV_GLOBALS_EXCLUDED_TOOLS="${EXCLUDED_TOOLS-agentsview}" bash "$SCRIPT"
}

It 'uninstalls the excluded tool and never reinstalls it'
When call run_installer
The status should be success
The output should include 'agentsview is excluded on this host, skipping'
The contents of file "$CALLS" should include 'tool uninstall agentsview'
The contents of file "$CALLS" should not include 'tool install agentsview'
The contents of file "$CALLS" should include 'tool install other-tool>=1.0'
The path "$TEST_HOME/.local/bin/python3-agentsview" should not be exist
The contents of file "$TEST_HOME/.agentsview/sessions.db" should equal 'preserved archive'
End

It 'removes excluded tools even when offline'
export NETWORK_STATUS=1
When call run_installer
The status should be success
The output should include 'Network unavailable'
The contents of file "$CALLS" should include 'tool uninstall agentsview'
The contents of file "$CALLS" should not include 'tool install '
End

It 'removes excluded tools before skipping boot-time installation'
export SYSTEMCTL_BIN="$TEST_HOME/bin/systemctl"
When call run_installer
The status should be success
The output should include 'System is booting'
The contents of file "$CALLS" should include 'tool uninstall agentsview'
End

It 'keeps the normal installation policy on other hosts'
EXCLUDED_TOOLS=''
export INSTALLED_CONTENT=''
When call run_installer
The status should be success
The output should include 'Installing agentsview>=0.42.0'
The contents of file "$CALLS" should include 'tool install agentsview>=0.42.0'
The contents of file "$CALLS" should not include 'tool uninstall'
End

It 'cleans a stale wrapper without uninstalling an absent package'
export INSTALLED_CONTENT='' NETWORK_STATUS=1
When call run_installer
The status should be success
The output should include 'Network unavailable'
The contents of file "$CALLS" should not include 'tool uninstall'
The path "$TEST_HOME/.local/bin/python3-agentsview" should not be exist
End

It 'fails closed when the installed-tool census fails'
export LIST_STATUS=42
When call run_installer
The status should equal 42
The contents of file "$CALLS" should not include 'tool uninstall'
The contents of file "$CALLS" should not include 'tool install '
The path "$TEST_HOME/.local/bin/python3-agentsview" should be exist
End

It 'does not continue after a failed uninstall'
export UNINSTALL_STATUS=43
When call run_installer
The status should equal 43
The contents of file "$CALLS" should not include 'tool install '
The path "$TEST_HOME/.local/bin/python3-agentsview" should be exist
End
End
