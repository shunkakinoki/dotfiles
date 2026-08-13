#!/usr/bin/env bash
# shellcheck disable=SC2016

Describe 'home-manager/services/mempalace-exporter/export.sh'
SCRIPT="$PWD/home-manager/services/mempalace-exporter/export.sh"
MODULE="$PWD/home-manager/services/mempalace-exporter/default.nix"

It 'uses strict Bash mode'
When run bash -c "head -3 '$SCRIPT'"
The status should be success
The output should include 'set -euo pipefail'
End

It 'resolves the installed package from the selected Python interpreter'
When run grep -F 'sysconfig.get_path("purelib")' "$SCRIPT"
The status should be success
The output should include 'MEMPALACE_PYTHON'
End

It 'exits successfully when mempalace is not installed'
TEMP_HOME=$(mktemp -d)
When run env HOME="$TEMP_HOME" bash "$SCRIPT"
The status should be success
The output should include 'mempalace not installed, skipping'
rm -rf "$TEMP_HOME"
End

Describe 'Python package selection'
setup_exporter_fixture() {
  TEMP_HOME=$(mktemp -d)
  tool_dir="$TEMP_HOME/.local/share/uv/tools/mempalace"
  mkdir -p \
    "$TEMP_HOME/.mempalace" \
    "$TEMP_HOME/bin" \
    "$tool_dir/bin" \
    "$tool_dir/lib/python3.11/site-packages" \
    "$tool_dir/lib/python3.12/site-packages"
  printf '{}\n' >"$TEMP_HOME/.mempalace/config.json"

  cat >"$tool_dir/bin/python" <<'PYTHON'
#!/usr/bin/env bash
code="${*: -1}"
case "$code" in
*json.load*)
  printf '%s\n' '/tmp/palace'
  ;;
*sysconfig.get_path*)
  printf '%s\n' "$HOME/.local/share/uv/tools/mempalace/lib/python3.12/site-packages"
  ;;
*export_palace*)
  printf '%s\n' "$code" >"$HOME/export-code"
  ;;
esac
PYTHON
  chmod +x "$tool_dir/bin/python"

  cat >"$TEMP_HOME/bin/git" <<'GIT'
#!/usr/bin/env bash
if [[ $1 == clone ]]; then
  destination="${*: -1}"
  mkdir -p "$destination/.git"
fi
if [[ $* == *'diff --cached --quiet'* ]]; then
  exit 0
fi
GIT
  chmod +x "$TEMP_HOME/bin/git"
}

cleanup_exporter_fixture() {
  rm -rf "$TEMP_HOME"
}

Before 'setup_exporter_fixture'
After 'cleanup_exporter_fixture'

It 'uses the selected interpreter site-packages when multiple versions exist'
When run env HOME="$TEMP_HOME" PATH="$TEMP_HOME/bin:$PATH" bash "$SCRIPT"
The status should be success
The output should include 'No palace changes'
The file "$TEMP_HOME/export-code" should be exist
The contents of file "$TEMP_HOME/export-code" should include 'lib/python3.12/site-packages'
The contents of file "$TEMP_HOME/export-code" should not include 'lib/python3.11/site-packages'
End
End

It 'declares both launchd and systemd schedules'
When run cat "$MODULE"
The status should be success
The output should include 'launchd.agents.mempalace-exporter'
The output should include 'systemd.user.timers.mempalace-exporter'
End
End
