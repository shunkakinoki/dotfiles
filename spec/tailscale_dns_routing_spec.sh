#!/usr/bin/env bash
# shellcheck disable=SC2329

Describe 'Managed Tailscale DNS acceptance'
setup() {
  TEST_ROOT=$(mktemp -d)
  export DNS_LOG="$TEST_ROOT/dns.log"
  touch "$DNS_LOG"
}

cleanup() { rm -rf "$TEST_ROOT"; }

run_activation() {
  tailscale_mock() {
    printf '%s\n' "$*" >>"$DNS_LOG"
    return "${TAILSCALE_STATUS:-0}"
  }
  id() { printf '0\n'; }
  readlink() { printf '/run/systemd/resolve/stub-resolv.conf\n'; }
  export -f tailscale_mock id readlink
  bash home-manager/modules/tailscale/activate-up.sh tailscale_mock "$@"
}

Before 'setup'
After 'cleanup'

It 'enables DNS acceptance while applying the other node flags'
When call run_activation --ssh=false
The status should be success
The contents of file "$DNS_LOG" should eq 'up --ssh=false --accept-dns=true'
End

It 'enables DNS acceptance when no other node flags are supplied'
When call run_activation
The status should be success
The contents of file "$DNS_LOG" should eq 'up --accept-dns=true'
End

It 'reports a failed Tailscale configuration instead of claiming success'
export TAILSCALE_STATUS=42
When call run_activation
The status should equal 42
The contents of file "$DNS_LOG" should eq 'up --accept-dns=true'
End
End
