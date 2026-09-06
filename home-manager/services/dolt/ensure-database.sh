#!/usr/bin/env bash

set -euo pipefail

repo_dir="${1:?repository directory required}"
remote_url="${2:?database remote required}"
database=$("@jq@/bin/jq" -er '.dolt_database | select(type == "string" and length > 0)' "$repo_dir/.beads/metadata.json" 2>/dev/null) || {
  echo "Cannot read configured Dolt database name" >&2
  exit 1
}
if [[ ! $database =~ ^[A-Za-z_][A-Za-z0-9_-]*$ ]]; then
  echo "Invalid configured Dolt database name" >&2
  exit 1
fi

sql=(
  "@dolt@/bin/dolt"
  --host "${BEADS_DOLT_SERVER_HOST:-127.0.0.1}"
  --port "${BEADS_DOLT_SERVER_PORT:-3307}"
  --user "${BEADS_DOLT_SERVER_USER:-root}"
  --no-tls sql --result-format json -q
)

# Query the server independently of Beads: ping alone cannot distinguish a
# missing database from an unavailable server or an incompatible schema.
databases=$("${sql[@]}" "SHOW DATABASES" 2>/dev/null) || {
  status=$?
  echo "Dolt server database discovery failed" >&2
  exit "$status"
}
database_exists=$("@jq@/bin/jq" -r --arg database "$database" '
  if (.rows | type) != "array" or any(.rows[]; (.Database | type) != "string")
  then error("invalid database inventory")
  else any(.rows[]; .Database == $database)
  end' <<<"$databases" 2>/dev/null) || {
  echo "Dolt server returned an invalid database inventory" >&2
  exit 1
}
if [ "$database_exists" = true ]; then
  exit 0
fi

# A new host may clone committed history. A host with preserved local data
# needs an explicit cutover so unpublished work is never silently orphaned.
for legacy_store in "$repo_dir/.beads/dolt/$database" "$repo_dir/.beads/dolt"; do
  if [ -f "$legacy_store/.dolt/noms/manifest" ]; then
    echo "Preserved local database requires a verified cutover before provisioning" >&2
    exit 1
  fi
done

# Remote URLs are configuration, never SQL. Reject SQL delimiters and control
# characters rather than accepting a connection string with embedded syntax.
if [[ $remote_url =~ ://[^/]*@ || $remote_url == *"?"* || $remote_url == *"#"* || $remote_url == *"'"* || $remote_url == *\\* || $remote_url == *$'\n'* || $remote_url == *$'\r'* ]]; then
  echo "Invalid database remote URL" >&2
  exit 1
fi

echo "Provisioning missing database from its configured remote"
# Native server cloning is a single create operation and can complete large
# transfers without the Beads bootstrap client's separate deadline. Existing
# databases are never dropped or reinitialized; a competing create fails.
"${sql[@]}" "CALL DOLT_CLONE('$remote_url', '$database')" >/dev/null 2>&1 || {
  status=$?
  echo "Dolt database clone failed" >&2
  exit "$status"
}
