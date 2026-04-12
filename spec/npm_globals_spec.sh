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
End
