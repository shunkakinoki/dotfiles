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
End
