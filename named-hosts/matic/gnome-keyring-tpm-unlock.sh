#!/usr/bin/env bash
# Unlocks the GNOME Keyring for the UID given as $1 with the TPM2 credential.
# Runs as root (TPM access), then uses runuser to speak the control socket
# protocol as that user, because the daemon identifies callers by SO_PEERCRED.
# @logger@, @systemd_creds@, @id@, @sleep@, @env@, @runuser@, @unlock_py@
# are substituted by pkgs.replaceVars.
log() { echo "gnome-keyring-tpm: $*" | @logger@ -t gnome-keyring-tpm; }
CRED="/etc/credstore.encrypted/gnome-keyring.cred"
[ -f "$CRED" ] || exit 0

TARGET_UID="$1"
if [ -z "$TARGET_UID" ]; then
  log "no target UID given"
  exit 1
fi
# Skip system/greeter users (uid < 1000)
[ "$TARGET_UID" -lt 1000 ] && exit 0

TARGET_USER=$(@id@ -nu "$TARGET_UID" 2>&1)
# shellcheck disable=SC2181
if [ $? -ne 0 ]; then
  log "failed to resolve user for UID '$TARGET_UID': $TARGET_USER"
  exit 1
fi

PW=$(@systemd_creds@ decrypt --name=gnome-keyring "$CRED" - 2>/dev/null)
# shellcheck disable=SC2181
if [ $? -ne 0 ] || [ -z "$PW" ]; then
  log "credential decrypt failed"
  exit 1
fi

# The daemon answers on the control socket before its p11-kit backend is fully
# initialized, and an unlock sent that early comes back DENIED, so retry.
SOCK="/run/user/$TARGET_UID/keyring/control"
for attempt in 1 2 3 4 5 6 7 8; do
  if [ -S "$SOCK" ]; then
    OUT=$(printf '%s' "$PW" |
      @runuser@ -u "$TARGET_USER" -- \
        @env@ XDG_RUNTIME_DIR="/run/user/$TARGET_UID" \
        @unlock_py@ 2>&1)
    STATUS=$?
    log "attempt $attempt: $OUT (exit $STATUS)"
    [ "$STATUS" -eq 0 ] && exit 0
  else
    log "attempt $attempt: socket not found"
  fi
  @sleep@ 3
done

log "all attempts exhausted - keyring was NOT unlocked for $TARGET_USER"
exit 1
