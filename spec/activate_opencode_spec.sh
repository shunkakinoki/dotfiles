#!/usr/bin/env bash
# shellcheck disable=SC2329,SC2034,SC2016

Describe 'config/opencode/activate.sh'
SCRIPT="$PWD/config/opencode/activate.sh"
PLUGIN_SPECS=(
  'cc-safety-net'
  'opencode-atuin-history'
  'opencode-claude-hooks'
  'opencode-runtime-fallback@0.2.3'
)

setup() {
  TEMP_HOME=$(mktemp -d)
  FAKE_OPENCODE="$TEMP_HOME/opencode"
  FAKE_BUN="$TEMP_HOME/bun"
  printf '%s\n' \
    '#!/usr/bin/env bash' \
    'set -euo pipefail' \
    'if [[ $1 == debug && $2 == config ]]; then' \
    '  [[ ${FAIL_DEBUG:-0} != 1 ]] || exit 1' \
    '  if [[ ${NO_NPM_PLUGINS:-0} == 1 ]]; then' \
    '    printf '\''{"plugin":["file:///tmp/local-plugin.ts"]}\n'\''' \
    '    exit 0' \
    '  fi' \
    '  printf '\''{"plugin":["cc-safety-net","opencode-atuin-history","opencode-claude-hooks","opencode-runtime-fallback@0.2.3","file:///tmp/local-plugin.ts"]}\n'\''' \
    '  exit 0' \
    'fi' >"$FAKE_OPENCODE"
  chmod +x "$FAKE_OPENCODE"
  printf '%s\n' \
    '#!/usr/bin/env bash' \
    'set -euo pipefail' \
    'printf "%s\n" "$*" >>"$HOME/bun-invocations"' \
    'plugin_root="$3"' \
    'plugin_spec="$7"' \
    '[[ ${FAIL_BUN_PLUGIN:-} != "$plugin_spec" ]] || exit 1' \
    'case "$plugin_spec" in @*/*@*) plugin_package="${plugin_spec%@*}" ;; @*/*) plugin_package="$plugin_spec" ;; *@*) plugin_package="${plugin_spec%@*}" ;; *) plugin_package="$plugin_spec" ;; esac' \
    'manifest="$plugin_root/node_modules/$plugin_package/package.json"' \
    'mkdir -p "$(dirname "$manifest")"' \
    ': >"$manifest"' >"$FAKE_BUN"
  chmod +x "$FAKE_BUN"
  mkdir -p "$TEMP_HOME/.config/opencode"
}

cleanup() {
  rm -rf "$TEMP_HOME"
}

BeforeEach 'setup'
AfterEach 'cleanup'

It 'materializes every declared npm plugin'
When run env HOME="$TEMP_HOME" XDG_CONFIG_HOME="$TEMP_HOME/.config" bash "$SCRIPT" "$FAKE_OPENCODE" "$(command -v jq)" "$FAKE_BUN"
The status should be success
The output should include 'OpenCode plugin ready: cc-safety-net'
The output should include 'OpenCode plugin ready: opencode-atuin-history'
The output should include 'OpenCode plugin ready: opencode-claude-hooks'
The output should include 'OpenCode plugin ready: opencode-runtime-fallback@0.2.3'
The file "$TEMP_HOME/.config/opencode/node_modules/cc-safety-net/package.json" should be exist
The file "$TEMP_HOME/.config/opencode/node_modules/opencode-atuin-history/package.json" should be exist
The file "$TEMP_HOME/.config/opencode/node_modules/opencode-claude-hooks/package.json" should be exist
The file "$TEMP_HOME/.config/opencode/node_modules/opencode-runtime-fallback/package.json" should be exist
The contents of file "$TEMP_HOME/bun-invocations" should include '--exact --minimum-release-age 0 cc-safety-net'
The contents of file "$TEMP_HOME/bun-invocations" should include '--exact --minimum-release-age 0 opencode-atuin-history'
The contents of file "$TEMP_HOME/bun-invocations" should include '--exact --minimum-release-age 0 opencode-claude-hooks'
The contents of file "$TEMP_HOME/bun-invocations" should include '--exact --minimum-release-age 0 opencode-runtime-fallback@0.2.3'
End

It 'skips installation when every configured plugin is already ready'
for plugin_spec in "${PLUGIN_SPECS[@]}"; do
  case "$plugin_spec" in
  *@*)
    plugin_package="${plugin_spec%@*}"
    ;;
  *)
    plugin_package="$plugin_spec"
    ;;
  esac
  manifest="$TEMP_HOME/.config/opencode/node_modules/$plugin_package/package.json"
  mkdir -p "$(dirname "$manifest")"
  : >"$manifest"
done
When run env HOME="$TEMP_HOME" XDG_CONFIG_HOME="$TEMP_HOME/.config" bash "$SCRIPT" "$FAKE_OPENCODE" "$(command -v jq)" "$FAKE_BUN"
The status should be success
The output should include 'OpenCode plugin already ready: cc-safety-net'
The output should include 'OpenCode plugin already ready: opencode-runtime-fallback@0.2.3'
The file "$TEMP_HOME/bun-invocations" should not be exist
End

It 'does not pass local file plugins to the package installer'
When run env HOME="$TEMP_HOME" XDG_CONFIG_HOME="$TEMP_HOME/.config" bash "$SCRIPT" "$FAKE_OPENCODE" "$(command -v jq)" "$FAKE_BUN"
The status should be success
The output should include 'OpenCode plugin ready: cc-safety-net'
The contents of file "$TEMP_HOME/bun-invocations" should not include 'local-plugin.ts'
End

It 'succeeds when there are no npm plugins to materialize'
When run env HOME="$TEMP_HOME" XDG_CONFIG_HOME="$TEMP_HOME/.config" NO_NPM_PLUGINS=1 bash "$SCRIPT" "$FAKE_OPENCODE" "$(command -v jq)" "$FAKE_BUN"
The status should be success
The output should equal ''
The file "$TEMP_HOME/bun-invocations" should not be exist
End

It 'fails closed when effective config cannot be resolved'
When run env HOME="$TEMP_HOME" XDG_CONFIG_HOME="$TEMP_HOME/.config" FAIL_DEBUG=1 bash "$SCRIPT" "$FAKE_OPENCODE" "$(command -v jq)" "$FAKE_BUN"
The status should be failure
The stderr should include 'failed to resolve effective OpenCode config'
The file "$TEMP_HOME/bun-invocations" should not be exist
End

It 'fails closed when Bun cannot materialize a configured plugin'
When run env HOME="$TEMP_HOME" XDG_CONFIG_HOME="$TEMP_HOME/.config" FAIL_BUN_PLUGIN=opencode-atuin-history bash "$SCRIPT" "$FAKE_OPENCODE" "$(command -v jq)" "$FAKE_BUN"
The status should be failure
The output should include 'OpenCode plugin ready: cc-safety-net'
The file "$TEMP_HOME/.config/opencode/node_modules/opencode-atuin-history/package.json" should not be exist
End
End
