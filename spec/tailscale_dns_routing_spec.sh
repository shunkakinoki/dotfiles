#!/usr/bin/env bash
# shellcheck disable=SC2329

Describe 'Tailnet DNS routing when global Tailscale DNS is disabled'
  setup() {
    TEST_ROOT=$(mktemp -d)
    export DNS_LOG="$TEST_ROOT/dns.log"
    export TAILNET_SUFFIX="example-tail.ts.net"
    touch "$DNS_LOG"
  }

  cleanup() {
    rm -rf "$TEST_ROOT"
  }

  run_activation() {
    tailscale_mock() {
      if [ "$1" = status ]; then
        printf '{"CurrentTailnet":{"MagicDNSSuffix":"%s"}}\n' "$TAILNET_SUFFIX"
      fi
    }
    resolvectl() { printf '%s\n' "$*" >>"$DNS_LOG"; }
    id() { printf '0\n'; }
    readlink() { printf '/run/systemd/resolve/stub-resolv.conf\n'; }
    export -f tailscale_mock resolvectl id readlink
    bash home-manager/modules/tailscale/activate-up.sh tailscale_mock "$@"
  }

  Before 'setup'
  After 'cleanup'

  It 'routes only the discovered tailnet domain to its private resolver'
    When call run_activation --accept-dns=false
    The status should be success
    The contents of file "$DNS_LOG" should eq "dns tailscale0 100.100.100.100
domain tailscale0 ~example-tail.ts.net
default-route tailscale0 no"
  End

  It 'leaves DNS untouched when Tailscale manages DNS'
    When call run_activation --accept-dns=true
    The status should be success
    The file "$DNS_LOG" should be empty file
  End

  It 'rejects a missing suffix before changing resolver routes'
    TAILNET_SUFFIX=""
    When call run_activation --accept-dns=false
    The status should be failure
    The file "$DNS_LOG" should be empty file
  End
End
