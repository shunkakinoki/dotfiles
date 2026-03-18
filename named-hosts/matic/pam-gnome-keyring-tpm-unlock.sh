#!/usr/bin/env bash
# PAM exec script: runs as root, decrypts TPM credential, then
# uses runuser to run the Python unlock as the target user.
# @logger@, @systemd_creds@, @id@, @sleep@, @env@, @runuser@, @unlock_py@
# are substituted by pkgs.replaceVars.
log() { echo "gnome-keyring-tpm: $*" | @logger@ -t gnome-keyring-tpm; }
CRED="/etc/credstore.encrypted/gnome-keyring.cred"
[ -f "$CRED" ] || exit 0

if [ -z "$PAM_USER" ]; then
  log "PAM_USER is not set"
  exit 1
fi

# Decrypt synchronously — requires root/TPM access (not available after fork).
PW=$(@systemd_creds@ decrypt --name=gnome-keyring "$CRED" - 2>/dev/null)
# shellcheck disable=SC2181
if [ $? -ne 0 ] || [ -z "$PW" ]; then
  log "credential decrypt failed"
  exit 1
fi

USER_UID=$(@id@ -u "$PAM_USER" 2>&1)
# shellcheck disable=SC2181
if [ $? -ne 0 ]; then
  log "failed to resolve UID for PAM_USER='$PAM_USER': $USER_UID"
  exit 1
fi
# Skip system/greeter users (uid < 1000)
[ "$USER_UID" -lt 1000 ] && exit 0

# The gnome-keyring-daemon p11-kit backend is not fully initialized at
# PAM session-open time — unlock attempts at this point return DENIED.
# Fork a background retry loop so login is never blocked; the daemon
# is ready within a few seconds of the user session starting.
SOCK="/run/user/$USER_UID/keyring/control"
(
  UNLOCKED=0
  for attempt in 1 2 3 4 5 6 7 8; do
    @sleep@ 3
    [ -S "$SOCK" ] || {
      log "attempt $attempt: socket not found"
      continue
    }
    OUT=$(printf '%s' "$PW" |
      @runuser@ -u "$PAM_USER" -- \
        @env@ XDG_RUNTIME_DIR="/run/user/$USER_UID" \
        @unlock_py@ 2>&1)
    STATUS=$?
    log "attempt $attempt: $OUT (exit $STATUS)"
    if [ "$STATUS" -eq 0 ]; then
      UNLOCKED=1
      break
    fi
  done
  [ "$UNLOCKED" -eq 0 ] && log "all attempts exhausted — keyring was NOT unlocked for $PAM_USER"
) &

exit 0
