#!/usr/bin/env bash
# Log in to Atuin from an agenix secret. `atuin login` is a no-op on a host that
# already has a session, and only it can tell: sessions live in meta.db, and a
# leftover plain-text session file survives logout.
# The secret holds the password on line 1 and the encryption key on line 2.
# Usage: atuin-login.sh <secret_file> <identity_key> <rage_bin> <atuin_bin> <timeout_bin> <ssh_keygen_bin> <username> <data_dir>
set -euo pipefail
SECRET_FILE="$1"
IDENTITY_KEY="$2"
RAGE_BIN="$3"
ATUIN_BIN="$4"
TIMEOUT_BIN="$5"
SSH_KEYGEN_BIN="$6"
USERNAME="$7"
DATA_DIR="$8"

if [[ ! -r $IDENTITY_KEY ]]; then
  exit 0
fi
# rage asks for an SSH key's passphrase before checking recipients, which would
# block unattended activation.
if ! "$SSH_KEYGEN_BIN" -y -P "" -f "$IDENTITY_KEY" >/dev/null 2>&1; then
  exit 0
fi
if ! SECRET="$("$RAGE_BIN" -d -i "$IDENTITY_KEY" "$SECRET_FILE" 2>/dev/null)"; then
  exit 0
fi

{
  IFS= read -r ATUIN_PASSWORD || true
  IFS= read -r ATUIN_ENCRYPTION_KEY || true
} <<<"$SECRET"
unset SECRET
if [[ -z $ATUIN_PASSWORD || -z $ATUIN_ENCRYPTION_KEY ]]; then
  echo "Warning: Atuin login secret is incomplete; skipping login" >&2
  exit 0
fi

# A different key makes login re-encrypt the store before it authenticates, and
# records the running daemon writes during that rewrite can be lost. Atuin
# accepts the key as a mnemonic or as base64, so either form counts as a match.
if [[ -f "$DATA_DIR/key" ]] &&
  [[ "$("$ATUIN_BIN" key 2>/dev/null || true)" != "$ATUIN_ENCRYPTION_KEY" ]] &&
  [[ "$("$ATUIN_BIN" key --base64 2>/dev/null || true)" != "$ATUIN_ENCRYPTION_KEY" ]]; then
  echo "Warning: local Atuin key differs from the fleet key; stop the daemon, back up $DATA_DIR and run 'atuin login' by hand" >&2
  exit 0
fi

# Secrets go through the environment so they never appear in process arguments.
export ATUIN_PASSWORD ATUIN_ENCRYPTION_KEY
# A failed or stalled login must not hold up activation on an offline host. The
# key check above means the timeout cannot interrupt a re-encryption.
STATUS=0
"$TIMEOUT_BIN" 60 "$ATUIN_BIN" login -u "$USERNAME" </dev/null >/dev/null || STATUS=$?
# Login saves the session before it checks the key against the server, and a
# later run sees that session and skips the check. A host that already had a
# session returns before either step, so a timed-out run's session is always
# its own and unverified. A wrong key logs itself out.
if [[ $STATUS -eq 124 ]]; then
  "$TIMEOUT_BIN" 10 "$ATUIN_BIN" logout </dev/null >/dev/null 2>&1 || true
fi
if [[ $STATUS -ne 0 ]]; then
  echo "Warning: Atuin login failed; the next activation retries it" >&2
fi
