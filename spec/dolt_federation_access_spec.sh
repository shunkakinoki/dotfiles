#!/usr/bin/env bash
# shellcheck disable=SC2016,SC2329

Describe 'Dolt federation access'
SCRIPT="$PWD/home-manager/services/dolt/federation-access.sh"

Describe 'script properties'
It 'uses strict bash mode and validates placeholder syntax'
When run bash -c "grep -F 'set -euo pipefail' '$SCRIPT' >/dev/null && sed 's|@[A-Za-z_][A-Za-z0-9_]*@|/usr|g' '$SCRIPT' | bash -n"
The status should be success
End

It 'exposes only dry-run and apply modes'
When run bash -c "grep -F -- '--dry-run | --apply' '$SCRIPT' >/dev/null && grep -F \"Usage: federation-access --dry-run|--apply\" '$SCRIPT' >/dev/null"
The status should be success
End
End

Describe 'runtime behavior'
setup_federation_access() {
  TEST_ROOT=$(mktemp -d)
  FAKE_TAILSCALE_ROOT="$TEST_ROOT/tailscale"
  FAKE_DOLT_ROOT="$TEST_ROOT/dolt"
  COREUTILS="$TEST_ROOT/coreutils"
  RENDERED_SCRIPT="$TEST_ROOT/federation-access.sh"
  TAILSCALE_LOG="$TEST_ROOT/tailscale.log"
  DOLT_LOG="$TEST_ROOT/dolt.log"
  DOLT_INVOCATION_LOG="$TEST_ROOT/dolt-invocations.log"
  jq_prefix=$(dirname "$(dirname "$(command -v jq)")")

  mkdir -p "$FAKE_TAILSCALE_ROOT/bin" "$FAKE_DOLT_ROOT/bin" "$COREUTILS/bin"
  : >"$TAILSCALE_LOG"
  : >"$DOLT_LOG"
  : >"$DOLT_INVOCATION_LOG"
  export DOLT_INVOCATION_LOG DOLT_LOG TAILSCALE_LOG
  ln -s "$(command -v timeout)" "$COREUTILS/bin/timeout"

  cat >"$FAKE_TAILSCALE_ROOT/bin/tailscale" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >>"$TAILSCALE_LOG"

case "${FAKE_TAILSCALE_MODE:-valid}" in
  missing)
    payload='{"BackendState":"Running","Peer":{"one":{"HostName":"client-one","TailscaleIPs":["100.64.1.1"]},"two":{"HostName":"client-two","TailscaleIPs":["100.64.1.2"]},"three":{"HostName":"client-three","TailscaleIPs":["100.64.1.3"]}}}'
    ;;
  ambiguous)
    payload='{"BackendState":"Running","Peer":{"one":{"HostName":"client-one","TailscaleIPs":["100.64.1.1"]},"duplicate":{"HostName":"client-one","TailscaleIPs":["100.64.1.9"]},"two":{"HostName":"client-two","TailscaleIPs":["100.64.1.2"]},"three":{"HostName":"client-three","TailscaleIPs":["100.64.1.3"]},"four":{"HostName":"client-four","TailscaleIPs":["100.64.1.4"]}}}'
    ;;
  invalid-ip)
    payload='{"BackendState":"Running","Peer":{"one":{"HostName":"client-one","TailscaleIPs":["100.64.1.256"]},"two":{"HostName":"client-two","TailscaleIPs":["100.64.1.2"]},"three":{"HostName":"client-three","TailscaleIPs":["100.64.1.3"]},"four":{"HostName":"client-four","TailscaleIPs":["100.64.1.4"]}}}'
    ;;
  non-tailnet)
    payload='{"BackendState":"Running","Peer":{"one":{"HostName":"client-one","TailscaleIPs":["192.0.2.10"]},"two":{"HostName":"client-two","TailscaleIPs":["100.64.1.2"]},"three":{"HostName":"client-three","TailscaleIPs":["100.64.1.3"]},"four":{"HostName":"client-four","TailscaleIPs":["100.64.1.4"]}}}'
    ;;
  injection)
    payload='{"BackendState":"Running","Peer":{"one":{"HostName":"client-one","TailscaleIPs":["100.64.1.1; DROP TABLE mysql.user; PRIVATE_TAILNET_PAYLOAD"]},"two":{"HostName":"client-two","TailscaleIPs":["100.64.1.2"]},"three":{"HostName":"client-three","TailscaleIPs":["100.64.1.3"]},"four":{"HostName":"client-four","TailscaleIPs":["100.64.1.4"]}}}'
    ;;
  *)
    payload='{"BackendState":"Running","Peer":{"one":{"HostName":"client-one","TailscaleIPs":["100.64.1.1"]},"two":{"HostName":"client-two","TailscaleIPs":["100.64.1.2"]},"three":{"HostName":"client-three","TailscaleIPs":["100.64.1.3"]},"four":{"HostName":"client-four","TailscaleIPs":["100.64.1.4"]}}}'
    ;;
esac

printf '%s\n' "$payload" | jq --arg mode "${FAKE_TAILSCALE_MODE:-valid}" '
  .CurrentTailnet = {MagicDNSSuffix: "example.ts.net"} |
  .Self = {DNSName: "hub.example.ts.net.", TailscaleIPs: ["100.64.1.1"]} |
  .Peer |= with_entries(.value += {
    DNSName: (.value.HostName + ".example.ts.net."), InNetworkMap: true, Online: false
  }) |
  if $mode == "foreign" then .Peer.four.DNSName = "foreign.other.ts.net."
  elif $mode == "removed" then .Peer.four.InNetworkMap = false
  elif $mode == "expired" then .Peer.four.Expired = true
  elif $mode == "no-identity" then del(.CurrentTailnet)
  else . end
'
EOF
  chmod +x "$FAKE_TAILSCALE_ROOT/bin/tailscale"

  cat >"$FAKE_DOLT_ROOT/bin/dolt" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >>"$DOLT_INVOCATION_LOG"

query=''
previous_argument=''
for argument in "$@"; do
  if [ "$previous_argument" = '-q' ]; then
    query="$argument"
    break
  fi
  previous_argument="$argument"
done
printf '%s\n' "$query" >>"$DOLT_LOG"

case "$query" in
  'SELECT User, Host, plugin, LENGTH(authentication_string) AS password_length FROM mysql.user')
    case "${FAKE_DOLT_MODE:-empty}" in
      password-conflict)
        printf '%s\n' 'PRIVATE_ACCOUNT_DATA' >&2
        printf '%s\n' '{"rows":[{"User":"root","Host":"100.64.1.1","plugin":"mysql_native_password","password_length":32}]}'
        ;;
      plugin-conflict)
        printf '%s\n' 'PRIVATE_ACCOUNT_DATA' >&2
        printf '%s\n' '{"rows":[{"User":"root","Host":"100.64.1.1","plugin":"caching_sha2_password","password_length":0}]}'
        ;;
      existing)
        printf '%s\n' '{"rows":[{"User":"root","Host":"100.64.1.1","plugin":"mysql_native_password","password_length":0},{"User":"root","Host":"100.64.1.2","plugin":"mysql_native_password","password_length":0},{"User":"root","Host":"100.64.1.3","plugin":"mysql_native_password","password_length":0},{"User":"root","Host":"100.64.1.4","plugin":"mysql_native_password","password_length":0}]}'
        ;;
      *)
        printf '%s\n' '{"rows":[]}'
        ;;
    esac
    ;;
  "CREATE USER IF NOT EXISTS "*)
    if [ "${FAKE_DOLT_MODE:-}" = 'grant-failure' ]; then
      printf '%s\n' 'PRIVATE_SQL_ERROR' >&2
      exit 42
    fi
    printf '%s\n' '{"rows":[]}'
    ;;
  "SHOW GRANTS FOR "*)
    if [ "${FAKE_DOLT_MODE:-}" = 'readback-failure' ]; then
      printf '%s\n' 'PRIVATE_SQL_ERROR' >&2
      exit 43
    fi
    grant_host=$(printf '%s\n' "$query" | awk -F "'" '{ print $4 }')
    case "${FAKE_DOLT_MODE:-}" in
      extra-grant)
        printf '%s\n' '{"rows":[["GRANT SUPER ON *.* TO `root`@`100.64.1.1`","GRANT CLONE_ADMIN ON *.* TO `root`@`100.64.1.1`","GRANT SELECT ON *.* TO `root`@`100.64.1.1`"]]}'
        ;;
      grant-option)
        printf '%s\n' '{"rows":[["GRANT SUPER ON *.* TO `root`@`100.64.1.1` WITH GRANT OPTION","GRANT CLONE_ADMIN ON *.* TO `root`@`100.64.1.1`"]]}'
        ;;
      *)
        printf '{"rows":[["GRANT SUPER ON *.* TO `root`@`%s`","GRANT CLONE_ADMIN ON *.* TO `root`@`%s`"]]}\n' "$grant_host" "$grant_host"
        ;;
    esac
    ;;
  *)
    printf '%s\n' '{"rows":[]}'
    ;;
esac
EOF
  chmod +x "$FAKE_DOLT_ROOT/bin/dolt"

  sed \
    -e "s|@coreutils@|$COREUTILS|g" \
    -e "s|@dolt@|$FAKE_DOLT_ROOT|g" \
    -e "s|@jq@|$jq_prefix|g" \
    -e "s|@tailscale@|$FAKE_TAILSCALE_ROOT|g" \
    "$SCRIPT" >"$RENDERED_SCRIPT"
  chmod +x "$RENDERED_SCRIPT"
}

cleanup_federation_access() {
  unset DOLT_INVOCATION_LOG DOLT_LOG TAILSCALE_LOG
  rm -rf "$TEST_ROOT"
}

Before 'setup_federation_access'
After 'cleanup_federation_access'

It 'performs a dry run without SQL writes'
When run env FAKE_DOLT_MODE=empty bash "$RENDERED_SCRIPT" --dry-run
The status should be success
The output should include 'Federation access: approved client plan validated (no changes)'
The output should not include 'PRIVATE_TAILNET_PAYLOAD'
The contents of file "$DOLT_LOG" should include 'SELECT User, Host, plugin'
The contents of file "$DOLT_LOG" should not include 'CREATE USER'
The contents of file "$DOLT_LOG" should not include 'GRANT SUPER'
End

It 'applies four exact host grants through loopback port 3309'
When run bash -c "env FAKE_DOLT_MODE=empty bash '$RENDERED_SCRIPT' --apply && test \"\$(awk '/^CREATE USER IF NOT EXISTS / { count++ } END { print count + 0 }' '$DOLT_LOG')\" -eq 4 && awk 'BEGIN { valid = 0 } { if (\$0 !~ /--host 127.0.0.1 --port 3309/) exit 1; valid = 1 } END { exit valid ? 0 : 1 }' '$DOLT_INVOCATION_LOG'"
The status should be success
The output should include 'Federation access: approved client grants verified'
The contents of file "$DOLT_LOG" should include '100.64.1.1'
The contents of file "$DOLT_LOG" should include '100.64.1.2'
The contents of file "$DOLT_LOG" should include '100.64.1.3'
The contents of file "$DOLT_LOG" should include '100.64.1.4'
The contents of file "$DOLT_LOG" should not include "'root'@'%'"
The contents of file "$DOLT_INVOCATION_LOG" should not include '--port 3307'
End

It 'does not depend on a fixed hostname inventory'
When run env FAKE_TAILSCALE_MODE=missing bash "$RENDERED_SCRIPT" --apply
The status should be success
The output should include 'approved client grants verified'
The contents of file "$DOLT_LOG" should not include '100.64.1.4'
End

It 'admits approved nodes even when their hostnames are duplicated'
When run env FAKE_TAILSCALE_MODE=ambiguous bash "$RENDERED_SCRIPT" --apply
The status should be success
The output should include 'approved client grants verified'
The contents of file "$DOLT_LOG" should include '100.64.1.9'
End

It 'excludes foreign shared-in machines'
When run env FAKE_TAILSCALE_MODE=foreign bash "$RENDERED_SCRIPT" --apply
The status should be success
The output should include 'approved client grants verified'
The contents of file "$DOLT_LOG" should not include '100.64.1.4'
End

It 'excludes peers removed from the authenticated network map'
When run env FAKE_TAILSCALE_MODE=removed bash "$RENDERED_SCRIPT" --apply
The status should be success
The output should include 'approved client grants verified'
The contents of file "$DOLT_LOG" should not include '100.64.1.4'
End

It 'excludes expired peers'
When run env FAKE_TAILSCALE_MODE=expired bash "$RENDERED_SCRIPT" --apply
The status should be success
The output should include 'approved client grants verified'
The contents of file "$DOLT_LOG" should not include '100.64.1.4'
End

It 'fails closed without a current tailnet identity'
When run env FAKE_TAILSCALE_MODE=no-identity bash "$RENDERED_SCRIPT" --apply
The status should equal 1
The stderr should include 'approved client addresses unavailable or invalid'
The contents of file "$DOLT_LOG" should equal ''
End

It 'rejects an invalid IP before any SQL access'
When run env FAKE_TAILSCALE_MODE=invalid-ip bash "$RENDERED_SCRIPT" --apply
The status should equal 1
The stderr should include 'approved client addresses unavailable or invalid'
The contents of file "$DOLT_LOG" should equal ''
The contents of file "$DOLT_INVOCATION_LOG" should equal ''
End

It 'rejects a non-Tailnet IP before any SQL access'
When run env FAKE_TAILSCALE_MODE=non-tailnet bash "$RENDERED_SCRIPT" --apply
The status should equal 1
The stderr should include 'approved client addresses unavailable or invalid'
The contents of file "$DOLT_LOG" should equal ''
The contents of file "$DOLT_INVOCATION_LOG" should equal ''
End

It 'rejects an injected address without printing the peer payload'
When run env FAKE_TAILSCALE_MODE=injection bash "$RENDERED_SCRIPT" --apply
The status should equal 1
The stderr should include 'approved client addresses unavailable or invalid'
The stderr should not include 'PRIVATE_TAILNET_PAYLOAD'
The output should not include 'PRIVATE_TAILNET_PAYLOAD'
The contents of file "$DOLT_LOG" should equal ''
The contents of file "$DOLT_INVOCATION_LOG" should equal ''
End

It 'rejects a nonempty existing password before SQL writes'
When run env FAKE_DOLT_MODE=password-conflict bash "$RENDERED_SCRIPT" --apply
The status should equal 1
The stderr should include 'existing account conflicts with approved policy'
The stderr should not include 'PRIVATE_ACCOUNT_DATA'
The output should not include 'PRIVATE_ACCOUNT_DATA'
The contents of file "$DOLT_LOG" should include 'SELECT User, Host, plugin'
The contents of file "$DOLT_LOG" should not include 'CREATE USER'
The contents of file "$DOLT_LOG" should not include 'GRANT SUPER'
End

It 'rejects an authentication plugin conflict before SQL writes'
When run env FAKE_DOLT_MODE=plugin-conflict bash "$RENDERED_SCRIPT" --apply
The status should equal 1
The stderr should include 'existing account conflicts with approved policy'
The stderr should not include 'PRIVATE_ACCOUNT_DATA'
The output should not include 'PRIVATE_ACCOUNT_DATA'
The contents of file "$DOLT_LOG" should include 'SELECT User, Host, plugin'
The contents of file "$DOLT_LOG" should not include 'CREATE USER'
The contents of file "$DOLT_LOG" should not include 'GRANT SUPER'
End

It 'redacts a grant failure'
When run env FAKE_DOLT_MODE=grant-failure bash "$RENDERED_SCRIPT" --apply
The status should equal 1
The stderr should include 'Federation access: mirror grant failed'
The stderr should not include 'PRIVATE_SQL_ERROR'
The output should not include 'PRIVATE_SQL_ERROR'
The contents of file "$DOLT_LOG" should include 'CREATE USER IF NOT EXISTS'
End

It 'redacts a grant readback failure'
When run env FAKE_DOLT_MODE=readback-failure bash "$RENDERED_SCRIPT" --apply
The status should equal 1
The stderr should include 'Federation access: mirror grant verification failed'
The stderr should not include 'PRIVATE_SQL_ERROR'
The output should not include 'PRIVATE_SQL_ERROR'
The contents of file "$DOLT_LOG" should include 'SHOW GRANTS FOR'
End

It 'rejects an extra privilege in grant readback'
When run env FAKE_DOLT_MODE=extra-grant bash "$RENDERED_SCRIPT" --apply
The status should equal 1
The stderr should include 'Federation access: mirror grants not confirmed'
The contents of file "$DOLT_LOG" should include 'SHOW GRANTS FOR'
End

It 'rejects grant option in grant readback'
When run env FAKE_DOLT_MODE=grant-option bash "$RENDERED_SCRIPT" --apply
The status should equal 1
The stderr should include 'Federation access: mirror grants not confirmed'
The contents of file "$DOLT_LOG" should include 'SHOW GRANTS FOR'
End

It 'reconciles existing accounts without replacing their authentication'
When run env FAKE_DOLT_MODE=existing bash "$RENDERED_SCRIPT" --apply
The status should be success
The output should include 'Federation access: approved client grants verified'
The contents of file "$DOLT_LOG" should include 'SELECT User, Host, plugin'
The contents of file "$DOLT_LOG" should include 'CREATE USER IF NOT EXISTS'
The contents of file "$DOLT_LOG" should not include 'ALTER USER'
The contents of file "$DOLT_LOG" should not include 'DROP USER'
End
End
End
