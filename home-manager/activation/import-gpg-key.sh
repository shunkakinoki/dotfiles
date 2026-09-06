#!/usr/bin/env bash
# Import GPG key from agenix-encrypted file
# Usage: import-gpg-key.sh <gpg_secret_file> <identity_key> <rage_bin> <gpg_bin> <key_fingerprint>
set -euo pipefail
GPG_SECRET_FILE="$1"
IDENTITY_KEY="$2"
RAGE_BIN="$3"
GPG_BIN="$4"
KEY_FINGERPRINT="$5"
umask 077

if [[ ! -f $GPG_SECRET_FILE ]]; then
  exit 0
fi

if "$GPG_BIN" --list-secret-keys 2>/dev/null | grep -q "$KEY_FINGERPRINT"; then
  exit 0
fi

echo "Importing GPG key from agenix..."
"$RAGE_BIN" -d -i "$IDENTITY_KEY" "$GPG_SECRET_FILE" | "$GPG_BIN" --batch --import
echo "GPG key imported successfully"
