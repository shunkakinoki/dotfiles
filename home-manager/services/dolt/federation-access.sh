#!/usr/bin/env bash
set -euo pipefail

# The mirror has its own privilege store. Resolve only explicitly approved
# clients; never grant wildcard access or copy credentials from the live DB.
mode=${1:---dry-run}
case "$mode" in
--dry-run | --apply) ;;
*)
  echo 'Usage: federation-access --dry-run|--apply' >&2
  exit 64
  ;;
esac

fail() {
  echo "Federation access: $1" >&2
  exit 1
}

sql() {
  @coreutils@/bin/timeout 15 @dolt@/bin/dolt \
    --host 127.0.0.1 --port 3309 --user root --password '' --no-tls \
    sql -r json -q "$1" 2>/dev/null
}

peers=$(@coreutils@/bin/timeout 15 @tailscale@/bin/tailscale status --json 2>/dev/null) || fail 'peer discovery failed'
# Validate the entire plan before touching SQL. Require one node per name,
# and accept only literal Tailscale addresses (also excludes SQL metacharacters).
addresses=$(printf '%s' "$peers" | @jq@/bin/jq -er --argjson clients '@federationClients@' '
  def tailnet_ip:
    if test("^[0-9]+\\.[0-9]+\\.[0-9]+\\.[0-9]+$") then
      split(".") | map(tonumber) |
      .[0] == 100 and .[1] >= 64 and .[1] <= 127 and
      all(.[]; . >= 0 and . <= 255)
    else test("^fd7a:115c:a1e0:[0-9a-f:]+$") end;
  . as $status |
  if .BackendState != "Running" then error("tailnet unavailable") else . end |
  [$clients[] as $client |
    [$status.Peer[]? | select(.HostName == $client)] |
    if length != 1 then error("missing or ambiguous client") else .[0] end |
    .TailscaleIPs |
    if type != "array" or length == 0 then error("missing addresses") else . end |
    .[] | if type == "string" and tailnet_ip then . else error("invalid address") end
  ] | unique | if length == 0 then error("empty plan") else .[] end
' 2>/dev/null) || fail 'approved client addresses unavailable or invalid'

accounts=$(sql "SELECT User, Host, plugin, LENGTH(authentication_string) AS password_length FROM mysql.user") || fail 'mirror account read failed'
while IFS= read -r address; do
  # Never replace an existing password or authentication plugin.
  printf '%s' "$accounts" | @jq@/bin/jq -e --arg host "$address" '
    .rows | type == "array" and
    all(.[]; if .User == "root" and .Host == $host then
      .plugin == "mysql_native_password" and (.password_length | tostring) == "0"
    else true end)
  ' >/dev/null 2>&1 || fail 'existing account conflicts with approved policy'
done <<<"$addresses"

if [ "$mode" = '--dry-run' ]; then
  echo 'Federation access: approved client plan validated (no changes)'
  exit 0
fi

while IFS= read -r address; do
  sql "CREATE USER IF NOT EXISTS 'root'@'$address' IDENTIFIED BY ''; GRANT SUPER, CLONE_ADMIN ON *.* TO 'root'@'$address';" >/dev/null || fail 'mirror grant failed'
  grants=$(sql "SHOW GRANTS FOR 'root'@'$address'") || fail 'mirror grant verification failed'
  printf '%s' "$grants" | @jq@/bin/jq -e --arg host "$address" '
    ([.rows[] | .[]] | sort) ==
    (["GRANT SUPER ON *.* TO `root`@`" + $host + "`",
      "GRANT CLONE_ADMIN ON *.* TO `root`@`" + $host + "`"] | sort)
  ' >/dev/null 2>&1 || fail 'mirror grants not confirmed'
done <<<"$addresses"
echo 'Federation access: approved client grants verified'
