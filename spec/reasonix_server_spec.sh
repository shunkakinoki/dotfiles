#!/usr/bin/env bash
# shellcheck disable=SC2329,SC2016

Describe 'Reasonix serve worker service'
SERVICE_DIR="$PWD/home-manager/services/reasonix"
START="$SERVICE_DIR/start.sh"
UNIT="$SERVICE_DIR/default.nix"
CLIENT="$PWD/home-manager/modules/local-scripts/reasonix-threads.sh"

It 'passes bash syntax check'
When run bash -n "$START"
The status should be success
End

It 'passes bash syntax check for the thread client'
When run bash -n "$CLIENT"
The status should be success
End

It 'binds an ephemeral loopback port and publishes it instead of a fixed port'
When run bash -c "grep -E '^  --addr 127\.0\.0\.1:0 \\\\$' '$START'"
The status should be success
The output should include '--addr 127.0.0.1:0'
End

It 'publishes the bound port and pid so attach clients need no constant'
When run bash -c "grep -E '^  --(port|pid)-file ' '$START'"
The status should be success
The output should include '--port-file'
The output should include '--pid-file'
End

It 'generates the token once and reuses it across restarts'
When run bash -c "grep -c 'TOKEN_FILE' '$START'"
The status should be success
# Declaration, emptiness guard, write, chmod, and the serve flag.
The output should include '5'
End

It 'loads the shared env so CLIProxy credentials resolve as interactively'
When run bash -c "grep -F 'load-env-file.sh' '$START'"
The status should be success
The output should include 'load-env-file.sh'
End

It 'supervises the worker so it survives exit and login'
check() {
  grep -c -F 'RunAtLoad = true' "$UNIT"
  grep -c -F 'KeepAlive = true' "$UNIT"
}
When call check
The line 1 of output should equal '1'
The line 2 of output should equal '1'
End

It 'restarts the worker under systemd on Linux hosts'
When run bash -c "grep -c -F 'Restart = \"always\"' '$UNIT'"
The status should be success
The output should equal '1'
End

It 'is gated to the host that carries the proof-of-concept worker'
When run bash -c "grep -F 'inputs.host.isGalactica' '$UNIT'"
The status should be success
The output should include 'inputs.host.isGalactica'
End

Describe 'thread client contract'
It 'reads the bound port and token from the worker state directory'
When run bash -c "grep -E '^(PORT_FILE|TOKEN_FILE)=' '$CLIENT'"
The status should be success
The output should include 'PORT_FILE='
The output should include 'TOKEN_FILE='
End

It 'addresses a thread by sessionPath rather than sessionId'
When run bash -c "grep -F 'session-id:' '$CLIENT'"
The status should be success
The output should include 'session-id:'
End

It 'selects a thread by sessionId for /resume, which does not read sessionPath'
When run bash -c "grep -c -F 'api POST /resume' '$CLIENT'"
The status should be success
# open and send both select the target thread first.
The output should equal '2'
End

It 'never passes sessionPath to /inbox/items, which has no such field'
# grep -c exits non-zero on a zero count, so read the number instead.
check() {
  grep -A3 -F 'api POST /inbox/items' "$CLIENT" | grep -c -F 'sessionPath' || true
}
When call check
The output should equal '0'
End

It 'selects the target thread before enqueuing, so send cannot land on the wrong one'
When run bash -c "grep -B5 -F 'api POST /inbox/items' '$CLIENT' | grep -c -F 'api POST /resume'"
The status should be success
The output should equal '1'
End

It 'steers through the turn-scoped queue operation'
When run bash -c "grep -F 'enqueue_steer' '$CLIENT'"
The status should be success
The output should include 'enqueue_steer'
End

It 'exposes the documented subcommands'
When run bash -c "grep -E '^  (status|list|open|new|send|steer|tail) ' '$CLIENT'"
The status should be success
The output should include 'steer <sessionId> <msg>'
End
End
End
