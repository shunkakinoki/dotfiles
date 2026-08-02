#!/usr/bin/env bash
# Install the managed Tokscale entry in the current user's crontab.
set -euo pipefail

CRON_COMMAND="${1:?usage: activate-cron.sh <command>}"
BEGIN_MARKER="# BEGIN home-manager tokscale"
END_MARKER="# END home-manager tokscale"

if ! command -v crontab >/dev/null 2>&1; then
  echo "crontab is required for the Tokscale schedule" >&2
  exit 1
fi

existing_crontab="$(crontab -l 2>/dev/null || true)"
filtered_crontab="$({
  printf '%s\n' "$existing_crontab"
} | awk -v begin="$BEGIN_MARKER" -v end="$END_MARKER" '
  $0 == begin { managed = 1; next }
  $0 == end { managed = 0; next }
  !managed { print }
')"

{
  if [ -n "$filtered_crontab" ]; then
    printf '%s\n' "$filtered_crontab"
  fi
  printf '%s\n' "$BEGIN_MARKER"
  printf '0 */3 * * * %s\n' "$CRON_COMMAND"
  printf '%s\n' "$END_MARKER"
} | crontab -
