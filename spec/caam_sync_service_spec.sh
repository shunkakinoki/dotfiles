#!/usr/bin/env bash
# shellcheck disable=SC2016,SC2329

Describe 'home-manager/services/caam'
SETUP="$PWD/home-manager/services/caam/setup.sh"
SYNC="$PWD/home-manager/services/caam/sync.sh"
NIX="$PWD/home-manager/services/caam/default.nix"
SERVICES_DEFAULT="$PWD/home-manager/services/default.nix"

It 'defines setup.sh'
The path "$SETUP" should be exist
End

It 'defines sync.sh'
The path "$SYNC" should be exist
End

It 'wires caam into services/default.nix'
When run bash -c "grep -E 'caam = import|^\s*caam$' '$SERVICES_DEFAULT'"
The output should include 'caam'
The status should be success
End

It 'runs sync discover --add during setup'
When run bash -c "grep -F 'sync discover --add' '$SETUP'"
The output should include 'sync discover --add'
The status should be success
End

It 'enables auto-sync during setup'
When run bash -c "grep -F 'sync enable' '$SETUP'"
The output should include 'sync enable'
The status should be success
End

It 'skips setup when caam binary is missing'
When run bash -c "grep -F 'caam not found' '$SETUP'"
The output should include 'caam not found'
The status should be success
End

It 'defines darwin launchd agents for daemon and sync'
When run bash -c "grep -E 'caam-daemon|caam-sync' '$NIX'"
The output should include 'caam-daemon'
The output should include 'caam-sync'
The status should be success
End

It 'defines linux systemd units for daemon and sync timer'
When run bash -c "grep -E 'systemd.user.(services|timers).caam' '$NIX'"
The output should include 'caam-daemon'
The output should include 'caam-sync'
The status should be success
End

It 'bootstraps the pool on home-manager activation'
When run bash -c "grep -F 'caamSyncSetup' '$NIX'"
The output should include 'caamSyncSetup'
The status should be success
End

It 'skips periodic sync when caam binary is missing'
When run env CAAM=/nonexistent/caam bash "$SYNC"
The stderr should include 'caam not found'
The status should be success
End

Describe 'setup peer filtering'
setup_peer_filtering() {
  mock_bin_setup
  TEMP_HOME="$(mktemp -d)"
  mkdir -p "$TEMP_HOME/.local/bin"

  cat >"$MOCK_BIN/caam" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >>"$MOCK_LOG"
EOF
  chmod +x "$MOCK_BIN/caam"

  cat >"$TEMP_HOME/.local/bin/hostname" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [[ ${MOCK_HOSTNAME_FAIL:-0} == 1 ]]; then
  exit 1
fi
printf '%s\n' "${MOCK_HOSTNAME_VALUE:-matic.example}"
EOF
  chmod +x "$TEMP_HOME/.local/bin/hostname"
  export TEMP_HOME
}

cleanup_peer_filtering() {
  rm -rf "$TEMP_HOME"
  mock_bin_cleanup
  unset TEMP_HOME MOCK_HOSTNAME_FAIL MOCK_HOSTNAME_VALUE
}

Before 'setup_peer_filtering'
After 'cleanup_peer_filtering'

It 'removes the full and short local hostnames while preserving remote peers'
When run bash -c 'HOME="$1" CAAM="$2" MOCK_HOSTNAME_VALUE=matic.example bash "$3" >/dev/null; cat "$4"' _ "$TEMP_HOME" "$MOCK_BIN/caam" "$SETUP" "$MOCK_LOG"
The output should include 'sync discover --add'
The output should include 'sync remove localhost --force'
The output should include 'sync remove matic.example --force'
The output should include 'sync remove matic --force'
The output should not include 'sync remove kyber --force'
The status should be success
End

It 'keeps setup successful when the local hostname is unavailable'
When run bash -c 'HOME="$1" CAAM="$2" MOCK_HOSTNAME_FAIL=1 bash "$3" >/dev/null; cat "$4"' _ "$TEMP_HOME" "$MOCK_BIN/caam" "$SETUP" "$MOCK_LOG"
The output should include 'sync remove localhost --force'
The output should not include 'sync remove matic --force'
The status should be success
End
End
End
