#!/usr/bin/env bash
# shellcheck disable=SC2329

Describe 'T3 native runtime preparation'
SCRIPT="$PWD/home-manager/services/t3-connect/connect.sh"
PREPARE="$PWD/home-manager/services/t3-connect/prepare-runtime.sh"
WRAPPER="$PWD/home-manager/services/t3-connect/runtime-npm.sh"
LAUNCHER="$PWD/home-manager/services/t3-connect/launch-service.sh"

setup() {
  mock_bin_setup npm npx prepare node
  T3_TEST_ROOT="$(mktemp -d)"
  export T3_TEST_ROOT
  export T3CODE_HOME="$T3_TEST_ROOT/t3"
  export npm_config_cache="$T3_TEST_ROOT/npm-cache"
  export T3_PREPARE_RUNTIME="$MOCK_BIN/prepare"
  export T3_REAL_NPM="$MOCK_BIN/npm"
  export T3_PTY_PROBE=pty-probe.cjs
  mkdir -p "$T3CODE_HOME/runtime/versions/.staging-test" "$npm_config_cache/_npx"
}

cleanup() {
  mock_bin_cleanup
  rm -rf "$T3_TEST_ROOT"
  unset T3_TEST_ROOT T3CODE_HOME npm_config_cache T3_PREPARE_RUNTIME T3_REAL_NPM T3_PTY_PROBE
}

Before 'setup'
After 'cleanup'

mock_registry() {
  cat >"$MOCK_BIN/npm" <<'MOCK'
#!/usr/bin/env bash
printf '%s\n' "npm $*" >>"$MOCK_LOG"
if [ "${1:-}" = view ]; then echo 1.2.3; fi
MOCK
}

warm_cache() {
  mock_registry
  mkdir -p "$npm_config_cache/_npx/cache/node_modules/node-pty"
  mkdir -p "$T3CODE_HOME/runtime/versions/1.2.3/node_modules/node-pty"
  bash "$SCRIPT"
  cat "$MOCK_LOG"
}

It 'warms the exact version and prepares cache and service runtimes'
When call warm_cache
The status should be success
The output should include 'npm view t3@nightly version'
The output should include 'npx --yes t3@1.2.3 --version'
The output should include "prepare $npm_config_cache/_npx/cache/"
The output should include "prepare $T3CODE_HOME/runtime/versions/1.2.3/"
End

It 'honors the release channel override'
export T3_CONNECT_TAG=latest
When call warm_cache
The status should be success
The output should include 'npm view t3@latest version'
End

It 'does not mask preparation failures'
mkdir -p "$T3CODE_HOME/runtime/versions/1.2.3/node_modules/node-pty"
printf '#!/usr/bin/env bash\nexit 23\n' >"$MOCK_BIN/prepare"
When run bash "$SCRIPT"
The status should equal 23
End

Describe 'native build verification'
make_runtime() {
  mkdir -p "$T3CODE_HOME/runtime/versions/1.2.3/node_modules/node-pty"
  printf '{}\n' >"$T3CODE_HOME/runtime/versions/1.2.3/package.json"
}
Before 'make_runtime'

mock_build() {
  cat >"$MOCK_BIN/node" <<'MOCK'
#!/usr/bin/env bash
printf '%s\n' "probe $*" >>"$MOCK_LOG"
[ -f "$T3_TEST_ROOT/built" ] && [ "${T3_TEST_PROBE_FAIL:-0}" = 0 ]
MOCK
  cat >"$MOCK_BIN/npm" <<'MOCK'
#!/usr/bin/env bash
printf '%s\n' "npm $*" >>"$MOCK_LOG"
if [ "$1" = rebuild ]; then
  touch "$T3_TEST_ROOT/built"
  exit "${T3_TEST_BUILD_EXIT:-0}"
fi
MOCK
}

prepare_runtime() {
  bash "$PREPARE" "$T3CODE_HOME/runtime/versions/1.2.3"
}

run_build() {
  mock_build
  prepare_runtime
}

It 'approves only node-pty and validates the rebuilt terminal'
When call run_build
The status should be success
The stderr should include 'Preparing T3 native terminal'
The contents of file "$MOCK_LOG" should include 'npm pkg set allowScripts.node-pty=true --json'
The contents of file "$MOCK_LOG" should include 'npm rebuild --ignore-scripts=false --foreground-scripts node-pty'
The contents of file "$MOCK_LOG" should include 'probe pty-probe.cjs'
End

It 'fails when npm returns success but the terminal still fails'
export T3_TEST_PROBE_FAIL=1
When call run_build
The status should be failure
The stderr should include 'Preparing T3 native terminal'
End

It 'preserves the native build exit status'
export T3_TEST_BUILD_EXIT=17
When call run_build
The status should equal 17
The stderr should include 'Preparing T3 native terminal'
End

It 'skips rebuilding a working terminal'
When call prepare_runtime
The status should be success
The contents of file "$MOCK_LOG" should not include 'npm'
End

It 'rejects a runtime missing node-pty'
When run bash "$PREPARE" "$T3CODE_HOME/runtime/versions/.staging-test"
The status should be failure
The stderr should include 'T3 runtime has no node-pty'
End
End

Describe 'synchronous update preparation'
install_candidate() {
  bash "$WRAPPER" install --prefix "$T3CODE_HOME/runtime/versions/.staging-test" --no-fund --no-audit t3@1.2.3
}

It 'prepares a staged update before returning success'
When call install_candidate
The status should be success
The contents of file "$MOCK_LOG" should include 't3@1.2.3 --ignore-scripts=true'
The contents of file "$MOCK_LOG" should include "prepare $T3CODE_HOME/runtime/versions/.staging-test"
End

It 'fails the update when terminal preparation fails'
printf '#!/usr/bin/env bash\nexit 23\n' >"$MOCK_BIN/prepare"
When call install_candidate
The status should equal 23
End

It 'prepares updates with reordered flags and an equals-form prefix'
When run bash "$WRAPPER" install --no-audit t3@1.2.3 "--prefix=$T3CODE_HOME/runtime/versions/.staging-test" --no-fund
The status should be success
The contents of file "$MOCK_LOG" should include "prepare $T3CODE_HOME/runtime/versions/.staging-test"
End

It 'does not prepare a failed installation'
printf '#!/usr/bin/env bash\nexit 19\n' >"$MOCK_BIN/npm"
When call install_candidate
The status should equal 19
The contents of file "$MOCK_LOG" should not include 'prepare'
End

It 'forwards unrelated npm calls unchanged'
When run bash "$WRAPPER" view t3@nightly version
The status should be success
The contents of file "$MOCK_LOG" should include 'npm view t3@nightly version'
The contents of file "$MOCK_LOG" should not include 'prepare'
The contents of file "$MOCK_LOG" should not include 'ignore-scripts'
End

It 'does not change npm policy for projects outside the T3 runtime'
When run bash "$WRAPPER" install --prefix "$T3_TEST_ROOT" --no-fund --no-audit t3@1.2.3
The status should be success
The contents of file "$MOCK_LOG" should not include 'prepare'
The contents of file "$MOCK_LOG" should not include 'ignore-scripts'
End

It 'does not follow a staging symlink outside the runtime'
ln -s "$T3_TEST_ROOT" "$T3CODE_HOME/runtime/versions/.staging-link"
When run bash "$WRAPPER" install --prefix "$T3CODE_HOME/runtime/versions/.staging-link" --no-fund --no-audit t3@1.2.3
The status should be success
The contents of file "$MOCK_LOG" should not include 'prepare'
The contents of file "$MOCK_LOG" should not include 'ignore-scripts'
End

It 'forwards installs into new unrelated directories unchanged'
When run bash "$WRAPPER" install --prefix "$T3_TEST_ROOT/new-project" --no-fund --no-audit t3@1.2.3
The status should be success
The contents of file "$MOCK_LOG" should not include 'prepare'
The contents of file "$MOCK_LOG" should not include 'ignore-scripts'
End
End

Describe 'service startup'
mock_active_version() {
  cat >"$MOCK_BIN/node" <<'MOCK'
#!/usr/bin/env bash
if [ "$1" = -e ]; then
  echo 1.2.3
else
  printf '%s\n' "launcher $*" >>"$MOCK_LOG"
fi
MOCK
}
Before 'mock_active_version'

It 'prepares the active runtime before starting the service launcher'
When run bash "$LAUNCHER"
The status should be success
The contents of file "$MOCK_LOG" should include "prepare $T3CODE_HOME/runtime/versions/1.2.3"
The contents of file "$MOCK_LOG" should include "launcher $T3CODE_HOME/runtime/service-launcher.mjs"
End

It 'does not launch a broken active runtime'
printf '#!/usr/bin/env bash\nexit 23\n' >"$MOCK_BIN/prepare"
When run bash "$LAUNCHER"
The status should equal 23
The contents of file "$MOCK_LOG" should not include 'launcher'
End
End
End
