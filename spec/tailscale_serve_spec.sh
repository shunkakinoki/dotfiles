#!/usr/bin/env bash
# shellcheck disable=SC2329

Describe 'activation/ensure-tailscale-serve.sh'
SCRIPT="$PWD/home-manager/activation/ensure-tailscale-serve.sh"
MATIC="$PWD/named-hosts/matic/default.nix"
KYBER="$PWD/named-hosts/kyber/default.nix"

Describe 'script properties'
It 'uses strict mode (set -euo pipefail)'
When run bash -c "head -20 '$SCRIPT'"
The output should include 'set -euo pipefail'
End

It 'requires both ports as arguments'
When run bash -c "cat '$SCRIPT'"
The output should include 'https port required'
The output should include 'local port required'
End
End

Describe 'safe degradation'
mock_daemon_down() {
  cat >"$MOCK_BIN/tailscale" <<'SH'
#!/usr/bin/env bash
[ "${1:-}" = status ] && exit 1
exit 0
SH
  chmod +x "$MOCK_BIN/tailscale"
}

setup() {
  mock_bin_setup tailscale sudo
}

cleanup() {
  mock_bin_cleanup
}

Before 'setup'
After 'cleanup'

# Activation must not hard-fail a switch just because tailscale is absent or
# the daemon is not up yet.
It 'skips when tailscale is not installed'
When run bash -c "PATH=/usr/bin:/bin bash '$SCRIPT' 443 3773 2>&1"
The output should include 'skipping serve setup'
The status should be success
End

# Activation runs with a minimal PATH, so a bare `command -v tailscale` finds
# nothing and the step silently never ran on either host.
It 'finds tailscale outside PATH'
When run bash -c "cat '$SCRIPT'"
The output should include '.nix-profile/bin/tailscale'
The output should include '/run/current-system/sw/bin/tailscale'
End

# serve needs root; aborting the switch over it would be worse than skipping.
It 'skips rather than failing when no sudo is available'
When run bash -c "cat '$SCRIPT'"
The output should include 'no sudo/doas available'
End

It 'skips when the daemon is not running'
When run bash -c "$(declare -f mock_daemon_down); mock_daemon_down; bash '$SCRIPT' 443 3773 2>&1"
The output should include 'skipping serve setup'
The status should be success
End
End

Describe 'idempotence'
setup() {
  mock_bin_setup sudo
  cat >"$MOCK_BIN/tailscale" <<'SH'
#!/usr/bin/env bash
printf '%s\n' "$0 $*" >>"$MOCK_LOG"
case "${1:-}" in
status) exit 0 ;;
serve)
  if [ "${2:-}" = status ]; then echo "|-- / proxy http://127.0.0.1:3773"; fi
  exit 0
  ;;
esac
exit 0
SH
  chmod +x "$MOCK_BIN/tailscale"
}

cleanup() {
  mock_bin_cleanup
}

Before 'setup'
After 'cleanup'

# tailscale serve persists in tailscaled state, so re-running activation must
# not re-issue the command.
It 'does nothing when the target is already served'
When run bash -c "bash '$SCRIPT' 443 3773 >/dev/null 2>&1; cat '$MOCK_LOG'"
The output should not include 'serve --bg'
The status should be success
End

It 'publishes when the target is not yet served'
When run bash -c "bash '$SCRIPT' 8443 9999 >/dev/null 2>&1; cat '$MOCK_LOG'"
The output should include 'serve --bg --https=8443 http://127.0.0.1:9999'
The status should be success
End
End

Describe 'host wiring'
# matic has nothing else on :443, so T3 takes the serve root.
It 'publishes T3 on 443 for matic'
When run bash -c "cat '$MATIC'"
The output should include 'ensure-tailscale-serve.sh}" 443 3773'
End

# openclaw owns :443 on kyber and the well-known path must be at the root, so
# T3 needs a distinct HTTPS port rather than a path prefix.
It 'publishes T3 on 8443 for kyber to avoid the openclaw root'
When run bash -c "cat '$KYBER'"
The output should include 'ensure-tailscale-serve.sh}" 8443 3773'
End
End

End
