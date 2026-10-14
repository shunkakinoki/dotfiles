#!/usr/bin/env bash
# Alert when the S3 auth backup lags the live auth cache. It only reads the
# auth directory: restoring an older copy would revoke the rotated token.
# shellcheck source=/dev/null
set -euo pipefail
. "@common@"

AUTH_DIR="${HOME}/.cli-proxy-api/objectstore/auths"
NOTIFY="${CLIPROXY_NOTIFY:-${HOME}/.local/scripts/pushover-notify}"
# Files written in the last few minutes may still be waiting on the watcher.
GRACE_MINUTES="${CLIPROXY_BACKUP_GRACE_MINUTES:-10}"
cliproxy_init_objectstore_env

problems=()

if ! cliproxy_has_objectstore_credentials; then
  problems+=("missing S3 credentials")
else
  while IFS= read -r -d '' file; do
    name="$(basename "$file")"
    if [ ! -r "$file" ]; then
      problems+=("${name}: not readable, never uploaded")
      continue
    fi
    local_sum="$(sha256sum <"$file" | cut -d' ' -f1)"
    if ! remote_sum="$(cliproxy_read_auth_from_s3 "$name" 2>/dev/null | sha256sum | cut -d' ' -f1)"; then
      problems+=("${name}: missing from S3")
    elif [ "$local_sum" != "$remote_sum" ]; then
      problems+=("${name}: S3 copy differs")
    fi
  done < <(find "$AUTH_DIR" -maxdepth 1 -type f -name '*.json' -mmin "+${GRACE_MINUTES}" -print0 2>/dev/null)
fi

if command -v systemctl >/dev/null 2>&1; then
  for unit in cliproxyapi-backup-auth.path cliproxyapi-backup-auth.service cliproxyapi-backup.service; do
    if ! state="$(systemctl --user show -p ActiveState --value "$unit" 2>&1)"; then
      problems+=("${unit}: cannot query systemd: ${state}")
    elif [ "$state" = "failed" ]; then
      problems+=("${unit} failed")
    fi
  done
fi

if [ "${#problems[@]}" -eq 0 ]; then
  echo "S3 auth backup is current"
  exit 0
fi

message="$(printf '%s\n' "${problems[@]}")"
printf '%s\n' "$message" >&2
if [ -x "$NOTIFY" ]; then
  "$NOTIFY" "cliproxy S3 backup stale" "$message" 1 || true
fi
exit 1
