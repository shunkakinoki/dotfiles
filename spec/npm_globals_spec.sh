#!/usr/bin/env bash
# shellcheck disable=SC2329

Describe 'npm-globals/install-npm-globals.sh'
SCRIPT="$PWD/home-manager/modules/npm-globals/install-npm-globals.sh"

Describe 'systemd activation skip'
It 'checks systemctl is-system-running to detect boot'
When run bash -c "grep 'is-system-running' '$SCRIPT'"
The output should include 'is-system-running'
End

It 'skips install during system boot'
When run bash -c "grep -A 1 'is-system-running' '$SCRIPT'"
The output should include 'skipping npm globals install'
End
End

Describe 'script properties'
It 'uses bash shebang'
When run bash -c "head -1 '$SCRIPT'"
The output should include '#!/usr/bin/env bash'
End

It 'uses strict mode'
When run bash -c "head -5 '$SCRIPT'"
The output should include 'set -euo pipefail'
End
End

Describe 'configuration'
It 'reads from dotfiles/package.json'
When run bash -c "grep 'PACKAGE_JSON=' '$SCRIPT'"
The output should include 'dotfiles/package.json'
End
End

Describe 'tool checks'
It 'checks for bun command'
When run bash -c "grep 'command -v bun' '$SCRIPT'"
The output should include 'bun'
End

It 'checks for jq command'
When run bash -c "grep 'command -v jq' '$SCRIPT'"
The output should include 'jq'
End
End

Describe 'file handling'
It 'exits gracefully when package.json is missing'
When run bash -c "grep -A 2 'if \[ ! -f' '$SCRIPT'"
The output should include 'exit 0'
End
End

Describe 'offline skip'
It 'checks network connectivity before installing'
When run bash -c "grep 'timeout 3 bash' '$SCRIPT'"
The output should include 'timeout 3 bash'
End

It 'exits gracefully when offline'
When run bash -c "grep -A 2 'Network unavailable' '$SCRIPT'"
The output should include 'exit 0'
End
End

Describe 'trusted dependencies'
It 'reads trustedDependencies from package.json'
When run bash -c "grep 'trustedDependencies' '$SCRIPT'"
The output should include 'trustedDependencies'
End

It 'trusts postinstall scripts before installing'
When run bash -c "grep 'bun pm -g trust' '$SCRIPT'"
The output should include 'bun pm -g trust'
End
End

Describe 'skip already installed'
It 'checks global node_modules for installed packages'
When run bash -c "grep 'GLOBAL_MODULES=' '$SCRIPT' | head -1"
The output should include '.bun/install/global/node_modules'
End

It 'reads installed version from package.json'
When run bash -c "grep 'installed_ver' '$SCRIPT'"
The output should include 'installed_ver'
End

It 'extracts wanted version from semver spec'
When run bash -c "grep 'wanted_ver' '$SCRIPT'"
The output should include 'wanted_ver'
End

It 'skips when installed version matches wanted'
When run bash -c "grep 'already installed, skipping' '$SCRIPT'"
The output should include 'already installed, skipping'
End

It 'uses sort -V for version comparison instead of exact match'
When run bash -c "grep 'sort -V' '$SCRIPT'"
The output should include 'sort -V'
End

It 'skips when installed version is newer than wanted'
# Simulate: installed=2.9.4, wanted=2.9.3 -> should skip (min is 2.9.3)
When run bash -c "printf '2.9.3\n2.9.4\n' | sort -V | head -n1"
The output should eq '2.9.3'
End

It 'skips when installed version equals wanted'
# Simulate: installed=2.1.92, wanted=2.1.92 -> should skip
When run bash -c "printf '2.1.92\n2.1.92\n' | sort -V | head -n1"
The output should eq '2.1.92'
End

It 'detects when installed version is older than wanted'
# Simulate: installed=0.65.0, wanted=0.65.2 -> min is 0.65.0, not 0.65.2
When run bash -c "printf '0.65.2\n0.65.0\n' | sort -V | head -n1"
The output should eq '0.65.0'
End

It 'detects when update is needed'
When run bash -c "grep 'updating' '$SCRIPT'"
The output should include 'updating'
End

It 'builds a MISSING array of packages to install'
When run bash -c "grep 'MISSING' '$SCRIPT'"
The output should include 'MISSING'
End
End

Describe 'per-package installation'
It 'uses bun add --global for each package'
When run bash -c "grep 'bun add --global' '$SCRIPT'"
The output should include 'bun add --global'
End

It 'installs one package at a time'
When run bash -c "grep 'bun add --global \"\$dep\"' '$SCRIPT'"
The output should include 'bun add --global'
End

It 'has a timeout per package'
When run bash -c "grep 'timeout.*bun add --global' '$SCRIPT'"
The output should include 'timeout'
End

It 'reports per-package failures'
When run bash -c "grep 'Install failed' '$SCRIPT'"
The output should include 'Install failed'
End

It 'reports when all packages are already installed'
When run bash -c "grep 'All npm global packages already installed' '$SCRIPT'"
The output should include 'All npm global packages already installed'
End
End

Describe 'dependency overrides'
It 'reads overrides from package.json'
When run bash -c "grep 'overrides' '$SCRIPT'"
The output should include 'overrides'
End

It 'applies overrides to global bun install'
When run bash -c "grep 'GLOBAL_PKG' '$SCRIPT'"
The output should include '.bun/install/global/package.json'
End

It 'runs bun install in global dir after applying overrides'
When run bash -c "grep 'cd.*bun/install/global.*bun install' '$SCRIPT'"
The output should include 'bun install'
End

It 'deduplicates nested copies of overridden packages'
When run bash -c "grep 'Deduplicated nested' '$SCRIPT'"
The output should include 'Deduplicated'
End

It 'finds nested node_modules with find command'
When run bash -c "grep 'find.*GLOBAL_MODULES' '$SCRIPT'"
The output should include 'find'
End
End

Describe 'bun npm shim purge'
  It 'defines a purge_bun_npm_shim function'
    When run bash -c "grep 'purge_bun_npm_shim()' '$SCRIPT'"
    The output should include 'purge_bun_npm_shim'
  End

  It 'removes the bun package from global node_modules'
    When run bash -c "grep 'rm -rf.*gm.*bun' '$SCRIPT'"
    The output should include 'bun'
  End

  It 'removes bun shims from .bin'
    When run bash -c "grep 'rm -f.*\.bin/bun' '$SCRIPT'"
    The output should include '.bin/bun'
  End

  It 'calls purge after each bun add --global'
    When run bash -c "grep -A 1 'bun add --global.*dep.*2>/dev/null' '$SCRIPT' | grep 'purge_bun_npm_shim'"
    The output should include 'purge_bun_npm_shim'
  End
End

Describe 'postinstall recovery'
  It 'defines a run_postinstall_if_needed function'
    When run bash -c "grep 'run_postinstall_if_needed()' '$SCRIPT'"
    The output should include 'run_postinstall_if_needed'
  End

  It 'checks for postinstall script in package.json'
    When run bash -c "grep 'scripts.postinstall' '$SCRIPT'"
    The output should include 'scripts.postinstall'
  End

  It 'skips packages that already have a native binary'
    When run bash -c "grep 'has_native=true' '$SCRIPT'"
    The output should include 'has_native'
  End

  It 'calls run_postinstall_if_needed after bun add'
    When run bash -c "grep -A 2 'bun add --global.*dep.*2>/dev/null' '$SCRIPT' | grep 'run_postinstall_if_needed'"
    The output should include 'run_postinstall_if_needed'
  End
End

Describe 'native addon repair'
It 'has a sqlite3 native binding repair step'
When run bash -c "grep 'repair_sqlite3_native_binding' '$SCRIPT'"
The output should include 'repair_sqlite3_native_binding'
End

It 'runs the sqlite3 package install script with foreground output'
When run bash -c "grep 'npm run install --foreground-scripts' '$SCRIPT'"
The output should include 'npm run install --foreground-scripts'
End

It 'verifies sqlite3 can be loaded by node'
When run bash -c "grep 'const sqlite3 = require' '$SCRIPT'"
The output should include 'const sqlite3 = require'
End
End

Describe 'native binary completeness'
It 'detects a missing platform-native optionalDependency'
When run bash -c "grep 'missing_native_optional_dep' '$SCRIPT'"
The output should include 'missing_native_optional_dep'
End

It 'derives current OS and CPU tokens for native deps'
When run bash -c "grep -E 'PLATFORM_OS=|PLATFORM_CPU=' '$SCRIPT'"
The output should include 'PLATFORM_OS'
End

It 'inspects optionalDependencies of installed packages'
When run bash -c "grep 'optionalDependencies' '$SCRIPT'"
The output should include 'optionalDependencies'
End

It 'reinstalls a version-matched package whose native binary is missing'
When run bash -c "grep 'installed but native binary missing' '$SCRIPT'"
The output should include 'reinstalling'
End
End

Describe 'native-binary reinstall integration'
setup() {
  TEMP_HOME=$(mktemp -d)
  MOCK_BIN=$(mktemp -d)
  MOCK_LOG="$TEMP_HOME/mock.log"
  REAL_BIN_DIR="$(dirname "$(command -v jq)")"
  REAL_SYSTEM_BIN_DIR="$(dirname "$(command -v mv)")"
  : >"$MOCK_LOG"

  GM="$TEMP_HOME/.bun/install/global/node_modules"
  mkdir -p "$TEMP_HOME/dotfiles" "$TEMP_HOME/.bun/install/global" "$TEMP_HOME/.bun/bin"

  cat >"$TEMP_HOME/dotfiles/package.json" <<'EOF'
{
  "dependencies": {
    "nativecli": "^1.0.0"
  }
}
EOF

  # Installed at the wanted version, but its platform-native optionalDependency
  # directory is absent -> must be reinstalled, not skipped.
  os_tok=$(uname -s | tr '[:upper:]' '[:lower:]')
  [ "$os_tok" = "darwin" ] || os_tok="linux"
  cpu_tok=$(uname -m)
  case "$cpu_tok" in arm64 | aarch64) cpu_tok=arm64 ;; *) cpu_tok=x64 ;; esac
  mkdir -p "$GM/nativecli"
  cat >"$GM/nativecli/package.json" <<EOF
{
  "name": "nativecli",
  "version": "1.0.0",
  "optionalDependencies": { "nativecli-${os_tok}-${cpu_tok}": "1.0.0" }
}
EOF

  cat >"$MOCK_BIN/timeout" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
shift
if [ "${1:-}" = "bash" ] && [ "${2:-}" = "-c" ] && [ "${3:-}" = "exec 3<>/dev/tcp/1.1.1.1/53" ]; then
  exit 0
fi
exec "$@"
EOF
  chmod +x "$MOCK_BIN/timeout"

  cat >"$MOCK_BIN/bun" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'bun %s\n' "$*" >>"$MOCK_LOG"
EOF
  chmod +x "$MOCK_BIN/bun"
}

cleanup() {
  rm -rf "$TEMP_HOME" "$MOCK_BIN"
}

Before 'setup'
After 'cleanup'

It 'reinstalls a package missing its platform-native binary'
When run bash -c "HOME='$TEMP_HOME' MOCK_LOG='$MOCK_LOG' PATH='$MOCK_BIN:$REAL_BIN_DIR:$REAL_SYSTEM_BIN_DIR:/usr/bin:/bin' bash '$SCRIPT' >/dev/null 2>&1; cat '$MOCK_LOG'"
The output should include 'bun add --global nativecli'
End
End

Describe 'stale global package pruning'
setup() {
  TEMP_HOME=$(mktemp -d)
  MOCK_BIN=$(mktemp -d)
  MOCK_LOG="$TEMP_HOME/mock.log"
  REAL_BIN_DIR="$(dirname "$(command -v jq)")"
  REAL_SYSTEM_BIN_DIR="$(dirname "$(command -v mv)")"
  : >"$MOCK_LOG"

  mkdir -p "$TEMP_HOME/dotfiles" "$TEMP_HOME/.bun/install/global" "$TEMP_HOME/.bun/bin"

  cat >"$TEMP_HOME/dotfiles/package.json" <<'EOF'
{
  "dependencies": {}
}
EOF

  cat >"$TEMP_HOME/.bun/install/global/package.json" <<'EOF'
{
  "dependencies": {
    "@beads/bd": "^0.63.3"
  }
}
EOF

  ln -sf ../install/global/node_modules/@beads/bd/bin/bd.js "$TEMP_HOME/.bun/bin/bd"

  cat >"$MOCK_BIN/timeout" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
shift
if [ "${1:-}" = "bash" ] && [ "${2:-}" = "-c" ] && [ "${3:-}" = "exec 3<>/dev/tcp/1.1.1.1/53" ]; then
  exit 0
fi
exec "$@"
EOF
  chmod +x "$MOCK_BIN/timeout"

  cat >"$MOCK_BIN/bun" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'bun %s\n' "$*" >>"$MOCK_LOG"
if [ "${1:-}" = "remove" ] && [ "${2:-}" = "--global" ] && [ "${3:-}" = "@beads/bd" ]; then
  jq 'del(.dependencies["@beads/bd"])' "$HOME/.bun/install/global/package.json" >"$HOME/.bun/install/global/package.json.tmp"
  mv "$HOME/.bun/install/global/package.json.tmp" "$HOME/.bun/install/global/package.json"
  rm -f "$HOME/.bun/bin/bd"
fi
EOF
  chmod +x "$MOCK_BIN/bun"
}

cleanup() {
  rm -rf "$TEMP_HOME" "$MOCK_BIN"
}

Before 'setup'
After 'cleanup'

It 'removes packages no longer declared in dotfiles package.json'
When run bash -c "HOME='$TEMP_HOME' MOCK_LOG='$MOCK_LOG' PATH='$MOCK_BIN:$REAL_BIN_DIR:$REAL_SYSTEM_BIN_DIR:/usr/bin:/bin' bash '$SCRIPT' >/dev/null 2>&1; cat '$MOCK_LOG'"
The output should include 'bun remove --global @beads/bd'
End

It 'removes stale package entries from bun global package.json'
When run bash -c "HOME='$TEMP_HOME' MOCK_LOG='$MOCK_LOG' PATH='$MOCK_BIN:$REAL_BIN_DIR:$REAL_SYSTEM_BIN_DIR:/usr/bin:/bin' bash '$SCRIPT' >/dev/null 2>&1; jq -r '.dependencies[\"@beads/bd\"] // \"missing\"' '$TEMP_HOME/.bun/install/global/package.json'"
The output should eq 'missing'
End

It 'removes dangling bun shims for stale packages'
When run bash -c "HOME='$TEMP_HOME' MOCK_LOG='$MOCK_LOG' PATH='$MOCK_BIN:$REAL_BIN_DIR:$REAL_SYSTEM_BIN_DIR:/usr/bin:/bin' bash '$SCRIPT' >/dev/null 2>&1; test -e '$TEMP_HOME/.bun/bin/bd' && echo present || echo missing"
The output should eq 'missing'
End
End

Describe 'aliased native binary (codex pattern)'
It 'reconstructs the platform suffix for aliased native deps'
When run bash -c "grep 'want_ver=\"\${base_ver}-\${suffix}\"' '$SCRIPT'"
The output should include 'want_ver'
End

It 'derives the native binary version from the installed parent'
When run bash -c "grep 'installed_base' '$SCRIPT'"
The output should include 'installed_base'
End

It 'reinstalls a phantom native dir instead of trusting -d'
When run bash -c "grep 'phantom dir' '$SCRIPT'"
The output should include 'phantom dir'
End

It 'warns when the payload did not materialize after install'
When run bash -c "grep 'still missing after install' '$SCRIPT'"
The output should include 'still missing after install'
End
End

Describe 'aliased native binary self-heal integration'
setup() {
  TEMP_HOME=$(mktemp -d)
  MOCK_BIN=$(mktemp -d)
  MOCK_LOG="$TEMP_HOME/mock.log"
  REAL_BIN_DIR="$(dirname "$(command -v jq)")"
  REAL_SYSTEM_BIN_DIR="$(dirname "$(command -v mv)")"
  : >"$MOCK_LOG"

  GM="$TEMP_HOME/.bun/install/global/node_modules"
  mkdir -p "$TEMP_HOME/dotfiles" "$TEMP_HOME/.bun/install/global" "$TEMP_HOME/.bun/bin"

  os_tok=$(uname -s | tr '[:upper:]' '[:lower:]')
  [ "$os_tok" = "darwin" ] || os_tok="linux"
  cpu_tok=$(uname -m)
  case "$cpu_tok" in arm64 | aarch64) cpu_tok=arm64 ;; *) cpu_tok=x64 ;; esac
  NATIVE_DEP="codexcli-${os_tok}-${cpu_tok}"
  # Wrapper is installed at 1.0.2 but the dotfiles optional pin is a stale,
  # SUFFIX-LESS 1.0.0 alias (the bug). The script must ignore both and install
  # the suffixed binary at the parent's actual version.
  WANT_SPEC="${NATIVE_DEP}@npm:codexcli@1.0.2-${os_tok}-${cpu_tok}"
  EXPECT_INSTALL="bun add --global ${WANT_SPEC}"

  cat >"$TEMP_HOME/dotfiles/package.json" <<EOF
{
  "dependencies": { "codexcli": "^1.0.0" },
  "optionalDependencies": { "${NATIVE_DEP}": "npm:codexcli@1.0.0" }
}
EOF

  # Parent installed ahead of the pin, no optionalDependencies of its own so the
  # parent-reinstall guard leaves it in place for the optional loop to read.
  mkdir -p "$GM/codexcli"
  cat >"$GM/codexcli/package.json" <<'EOF'
{ "name": "codexcli", "version": "1.0.2" }
EOF

  cat >"$MOCK_BIN/timeout" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
shift
if [ "${1:-}" = "bash" ] && [ "${2:-}" = "-c" ] && [ "${3:-}" = "exec 3<>/dev/tcp/1.1.1.1/53" ]; then
  exit 0
fi
exec "$@"
EOF
  chmod +x "$MOCK_BIN/timeout"

  cat >"$MOCK_BIN/bun" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'bun %s\n' "$*" >>"$MOCK_LOG"
EOF
  chmod +x "$MOCK_BIN/bun"
}

cleanup() {
  rm -rf "$TEMP_HOME" "$MOCK_BIN"
}

Before 'setup'
After 'cleanup'

It 'installs the suffixed binary at the installed parent version despite a stale bare pin'
When run bash -c "HOME='$TEMP_HOME' MOCK_LOG='$MOCK_LOG' PATH='$MOCK_BIN:$REAL_BIN_DIR:$REAL_SYSTEM_BIN_DIR:/usr/bin:/bin' bash '$SCRIPT' >/dev/null 2>&1; cat '$MOCK_LOG'"
The output should include "$EXPECT_INSTALL"
End

It 'reinstalls a phantom empty native dir'
When run bash -c "mkdir -p '$GM/$NATIVE_DEP'; HOME='$TEMP_HOME' MOCK_LOG='$MOCK_LOG' PATH='$MOCK_BIN:$REAL_BIN_DIR:$REAL_SYSTEM_BIN_DIR:/usr/bin:/bin' bash '$SCRIPT' >/dev/null 2>&1; cat '$MOCK_LOG'"
The output should include "$EXPECT_INSTALL"
End

It 'skips a native dir already at the correct version'
When run bash -c "mkdir -p '$GM/$NATIVE_DEP'; printf '{\"version\":\"1.0.2-${os_tok}-${cpu_tok}\"}' >'$GM/$NATIVE_DEP/package.json'; HOME='$TEMP_HOME' MOCK_LOG='$MOCK_LOG' PATH='$MOCK_BIN:$REAL_BIN_DIR:$REAL_SYSTEM_BIN_DIR:/usr/bin:/bin' bash '$SCRIPT' >/dev/null 2>&1; cat '$MOCK_LOG'"
The output should not include "bun add --global $NATIVE_DEP"
End
End
End
