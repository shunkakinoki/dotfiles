#!/usr/bin/env bash
# Log in to Atuin from an agenix secret when this host has no session yet.
# The secret holds the password on line 1 and the encryption key on line 2.
# Usage: atuin-login.sh <secret_file> <identity_key> <rage_bin> <atuin_bin> <username> <session_file>
set -euo pipefail
SECRET_FILE="$1"
IDENTITY_KEY="$2"
RAGE_BIN="$3"
ATUIN_BIN="$4"
USERNAME="$5"
SESSION_FILE="$6"

if [[ -s $SESSION_FILE ]]; then
  exit 0
fi

# Hosts outside the secret's recipients stay logged out, like kamino workers
# that should not download the whole fleet's thread store.
if [[ ! -r $IDENTITY_KEY ]]; then
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

# Secrets go through the environment so they never appear in process arguments.
export ATUIN_PASSWORD ATUIN_ENCRYPTION_KEY
# A failed login must not fail activation on a host that is offline.
if "$ATUIN_BIN" login -u "$USERNAME" </dev/null >/dev/null 2>&1; then
  echo "Logged in to Atuin as $USERNAME"
else
  echo "Warning: Atuin login failed; sync stays off until the next activation" >&2
fi
