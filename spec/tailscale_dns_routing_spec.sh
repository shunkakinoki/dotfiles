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
    if [ "$1" = up ] && [ -n "${EXISTING_HOSTNAME:-}" ]; then
      case " $* " in
      *" --hostname=$EXISTING_HOSTNAME "*) ;;
      *) return 1 ;;
      esac
    fi
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

It 'updates DNS without enrollment when no node flags are supplied'
When call run_activation
The status should be success
The contents of file "$DNS_LOG" should eq 'set --accept-dns=true'
End

It 'preserves an enrolled node hostname on repeated activation'
export EXISTING_HOSTNAME=kamino3
activate_twice() {
  run_activation "$@" && run_activation "$@"
}
When call activate_twice
The status should be success
The contents of file "$DNS_LOG" should eq 'set --accept-dns=true
set --accept-dns=true'
End

It 'passes explicit enrollment arguments through unchanged'
export EXISTING_HOSTNAME=kamino3
When call run_activation --hostname=kamino3 --ssh=false
The status should be success
The contents of file "$DNS_LOG" should eq 'up --hostname=kamino3 --ssh=false --accept-dns=true'
End

It 'reports a failed Tailscale configuration instead of claiming success'
export TAILSCALE_STATUS=42
When call run_activation
The status should equal 42
The contents of file "$DNS_LOG" should eq 'set --accept-dns=true'
End

It 'reports an explicit enrollment failure'
export TAILSCALE_STATUS=42
When call run_activation --hostname=kamino3 --ssh=false
The status should equal 42
The contents of file "$DNS_LOG" should eq 'up --hostname=kamino3 --ssh=false --accept-dns=true'
End
End
