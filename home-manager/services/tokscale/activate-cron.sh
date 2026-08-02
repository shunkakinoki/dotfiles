#!/usr/bin/env bash
# Install the managed Tokscale entry in the current user's crontab.
set -euo pipefail

CRON_COMMAND="${1:?usage: activate-cron.sh <command>}"
AWK_COMMAND="${AWK_BIN:-@awk@}"
BEGIN_MARKER="# BEGIN home-manager tokscale"
END_MARKER="# END home-manager tokscale"

resolve_crontab() {
  if [ -n "${CRONTAB_BIN:-}" ]; then
    printf '%s\n' "$CRONTAB_BIN"
  elif command -v crontab >/dev/null 2>&1; then
    command -v crontab
  elif [ -x /run/wrappers/bin/crontab ]; then
    # NixOS exposes setuid programs through wrappers, which are not on the
    # Home Manager activation PATH.
    printf '%s\n' /run/wrappers/bin/crontab
  elif [ -x /usr/bin/crontab ]; then
    printf '%s\n' /usr/bin/crontab
  else
    return 1
  fi
}

if ! CRONTAB_COMMAND="$(resolve_crontab)"; then
  echo "crontab is required for the Tokscale schedule" >&2
  exit 1
fi

existing_crontab="$("$CRONTAB_COMMAND" -l 2>/dev/null || true)"
filtered_crontab="$({
  printf '%s\n' "$existing_crontab"
} | "$AWK_COMMAND" -v begin="$BEGIN_MARKER" -v end="$END_MARKER" '
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
} | "$CRONTAB_COMMAND" -
