#!/usr/bin/env bash
# shellcheck disable=SC2329

Describe 't3-connect/connect.sh'
SCRIPT="$PWD/home-manager/services/t3-connect/connect.sh"

setup() {
  mock_bin_setup npx npm
  FAKE_HOME="$(mktemp -d)"
  export HOME="$FAKE_HOME"
}

cleanup() {
  mock_bin_cleanup
  rm -rf "$FAKE_HOME"
}

Before 'setup'
After 'cleanup'

Describe 'cache warming'
# npx keys its cache dir on the literal spec string, so the script must warm
# the resolved version the client uses, not the tag.
mock_npm_view() {
  cat >"$MOCK_BIN/npm" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$0 $*" >>"$MOCK_LOG"
if [ "${1:-}" = view ]; then echo "0.0.33-nightly.20260809.1041"; fi
exit 0
EOF
  chmod +x "$MOCK_BIN/npm"
}

It 'resolves the tag to an exact version before warming'
When run bash -c "$(declare -f mock_npm_view); mock_npm_view; bash '$SCRIPT' >/dev/null 2>&1; cat '$MOCK_LOG'"
The output should include 'npm view t3@nightly version'
The output should include 'npx --yes t3@0.0.33-nightly.20260809.1041 --version'
The status should be success
End

It 'honors T3_CONNECT_TAG override'
When run bash -c "$(declare -f mock_npm_view); mock_npm_view; T3_CONNECT_TAG=latest bash '$SCRIPT' >/dev/null 2>&1; cat '$MOCK_LOG'"
The output should include 'npm view t3@latest version'
The status should be success
End

It 'falls back to the tag when resolution fails'
When run bash -c "bash '$SCRIPT' >/dev/null 2>&1; cat '$MOCK_LOG'"
The output should include 'npx --yes t3@nightly --version'
The status should be success
End
End

Describe 'node-pty rebuild'
make_cache_dir() {
  mkdir -p "$HOME/.npm/_npx/abc123/node_modules/node-pty"
}

It 'rebuilds node-pty with a scoped ignore-scripts override'
When run bash -c "$(declare -f make_cache_dir); make_cache_dir; bash '$SCRIPT' >/dev/null 2>&1; cat '$MOCK_LOG'"
The output should include 'npm rebuild --ignore-scripts=false node-pty'
The status should be success
End

It 'skips rebuild when pty.node is already built'
When run bash -c "$(declare -f make_cache_dir); make_cache_dir; mkdir -p \"\$HOME/.npm/_npx/abc123/node_modules/node-pty/build/Release\"; touch \"\$HOME/.npm/_npx/abc123/node_modules/node-pty/build/Release/pty.node\"; bash '$SCRIPT' >/dev/null 2>&1; cat '$MOCK_LOG'"
The output should not include 'npm rebuild'
The status should be success
End

It 'succeeds when no npx cache dirs exist'
When run bash "$SCRIPT"
The status should be success
End

make_runtime_dir() {
  mkdir -p "$HOME/.t3/runtime/versions/1.2.3/node_modules/node-pty"
}

It 'also builds node-pty in the t3 service runtime tree'
When run bash -c "$(declare -f make_runtime_dir); make_runtime_dir; bash '$SCRIPT' >/dev/null 2>&1; cat '$MOCK_LOG'"
The output should include 'npm rebuild --ignore-scripts=false node-pty'
The status should be success
End
End

Describe 'systemd unit PATH'
UNIT="$PWD/home-manager/services/t3-connect/default.nix"

# node-gyp's generated Makefile shells out to these. Omitting them fails the
# build with `sed: command not found`, which names none of the real cause.
It 'includes the build tools node-gyp shells out to'
When run bash -c "cat '$UNIT'"
The output should include 'pkgs.gnused'
The output should include 'pkgs.gnugrep'
The output should include 'pkgs.gawk'
The output should include 'pkgs.which'
End

It 'includes a compiler, make and python for node-gyp'
When run bash -c "cat '$UNIT'"
The output should include 'pkgs.gcc'
The output should include 'pkgs.gnumake'
The output should include 'pkgs.python3'
End
End

Describe 'toolchain selection'
It 'documents the nix/system glibc mismatch'
When run bash -c "cat '$SCRIPT'"
The output should include 'GLIBC'
The output should include '/etc/NIXOS'
End
End

Describe 'script properties'
It 'uses strict mode (set -euo pipefail)'
When run bash -c "head -20 '$SCRIPT'"
The output should include 'set -euo pipefail'
End

It 'documents why the scoped override is needed'
When run bash -c "cat '$SCRIPT'"
The output should include 'per-package allowlist'
End
End

End
