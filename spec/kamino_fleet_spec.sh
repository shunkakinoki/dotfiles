#!/usr/bin/env bash
Describe 'kamino-fleet'
SCRIPT="$PWD/named-hosts/kamino/fleet.sh"

setup() {
  TEST_ROOT=$(mktemp -d)
  mkdir -p "$TEST_ROOT/bin"
  jq -n '{machines: [{name: "kamino1", hostname: "kamino1.example.ts.net", user: "root"}]}' >"$TEST_ROOT/inventory.json"
cat >"$TEST_ROOT/bin/tailscale" <<'EOF'
#!/usr/bin/env bash
if [ "$1 $2" = "status --json" ]; then
  case "${FLEET_MODE:-healthy}" in
    healthy) printf '%s\n' '{"BackendState":"Running","Peer":{"node-1":{"ID":"node-1","DNSName":"kamino1.example.ts.net.","Online":true,"TailscaleIPs":["100.64.0.1"]}}}' ;;
    sshfail|wrongprobe) printf '%s\n' '{"BackendState":"Running","Peer":{"node-1":{"ID":"node-1","DNSName":"kamino1.example.ts.net.","Online":true,"TailscaleIPs":["100.64.0.1"]}}}' ;;
    offline) printf '%s\n' '{"BackendState":"Running","Peer":{"node-1":{"ID":"node-1","DNSName":"kamino1.example.ts.net.","Online":false,"TailscaleIPs":["100.64.0.1"]}}}' ;;
    duplicate) printf '%s\n' '{"BackendState":"Running","Peer":{"node-1":{"ID":"node-1","DNSName":"kamino1.example.ts.net.","Online":true,"TailscaleIPs":["100.64.0.1"]},"node-2":{"ID":"node-2","DNSName":"kamino1.example.ts.net.","Online":true,"TailscaleIPs":["100.64.0.2"]}}}' ;;
    badip) printf '%s\n' '{"BackendState":"Running","Peer":{"node-1":{"ID":"node-1","DNSName":"kamino1.example.ts.net.","Online":true,"TailscaleIPs":["not-an-ip"]}}}' ;;
    unauth) printf '%s\n' '{"BackendState":"NeedsLogin","Peer":{}}' ;;
  esac
elif [ "$1" = ssh ]; then
  [ "${FLEET_MODE:-healthy}" != sshfail ] || exit 1
  if [ "${FLEET_MODE:-healthy}" = wrongprobe ]; then
    printf '%s\n' ubuntu kamino2.example.ts.net 'private-data'
  else
    printf '%s\n' root kamino1.example.ts.net 'herdr 1' 'tmux 3' 'zellij 1' active
  fi
fi
EOF
  chmod +x "$TEST_ROOT/bin/tailscale"
}
cleanup() { rm -rf "$TEST_ROOT"; }
Before setup
After cleanup

It 'lists declared machines without contacting Tailscale'
When run env PATH="$TEST_ROOT/bin:$PATH" bash "$SCRIPT" --inventory "$TEST_ROOT/inventory.json" list --json
The status should be success
The output should include '"status": "declared"'
End

It 'verifies a healthy machine through Tailscale SSH'
When run env PATH="$TEST_ROOT/bin:$PATH" bash "$SCRIPT" --inventory "$TEST_ROOT/inventory.json" verify --json
The status should be success
The output should include '"status": "pass"'
The output should include '"node_id": "node-1"'
End

It 'fails closed when no machine matches the pattern'
When run env PATH="$TEST_ROOT/bin:$PATH" bash "$SCRIPT" --inventory "$TEST_ROOT/inventory.json" list kamino9
The status should equal 2
The error should include 'No declared machines match'
End

It 'fails closed for unauthenticated Tailscale state'
When run env FLEET_MODE=unauth PATH="$TEST_ROOT/bin:$PATH" bash "$SCRIPT" --inventory "$TEST_ROOT/inventory.json" verify --json
The status should equal 2
The error should include 'not running and authenticated'
End

It 'fails closed for malformed Tailscale addresses'
When run env FLEET_MODE=badip PATH="$TEST_ROOT/bin:$PATH" bash "$SCRIPT" --inventory "$TEST_ROOT/inventory.json" verify --json
The status should equal 1
The output should include 'missing or invalid Tailscale IP'
End

It 'reports offline machines'
When run env FLEET_MODE=offline PATH="$TEST_ROOT/bin:$PATH" bash "$SCRIPT" --inventory "$TEST_ROOT/inventory.json" verify --json
The status should equal 1
The output should include 'offline'
End

It 'reports duplicate DNS names'
When run env FLEET_MODE=duplicate PATH="$TEST_ROOT/bin:$PATH" bash "$SCRIPT" --inventory "$TEST_ROOT/inventory.json" verify --json
The status should equal 1
The output should include 'duplicate DNS name'
End

It 'reports SSH probe failures'
When run env FLEET_MODE=sshfail PATH="$TEST_ROOT/bin:$PATH" bash "$SCRIPT" --inventory "$TEST_ROOT/inventory.json" verify --json
The status should equal 1
The output should include 'SSH or tools/service probe failed'
End

It 'does not leak SSH probe output'
When run env FLEET_MODE=wrongprobe PATH="$TEST_ROOT/bin:$PATH" bash "$SCRIPT" --inventory "$TEST_ROOT/inventory.json" verify --json
The status should equal 1
The output should not include 'private-data'
End
End
