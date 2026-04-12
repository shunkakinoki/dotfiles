#!/usr/bin/env bash
# Import GPG key from agenix-encrypted file
# Usage: import-gpg-key.sh <gpg_secret_file> <identity_key> <agenix_dir> <rage_bin> <gpg_bin> <key_fingerprint>
set -euo pipefail
GPG_SECRET_FILE="$1"
IDENTITY_KEY="$2"
AGENIX_DIR="$3"
RAGE_BIN="$4"
GPG_BIN="$5"
KEY_FINGERPRINT="$6"
GPG_TEMP_FILE="$AGENIX_DIR/gpg.key"

mkdir -p "$AGENIX_DIR"

if [[ ! -f "$GPG_SECRET_FILE" ]]; then
  exit 0
fi

if "$GPG_BIN" --list-secret-keys 2>/dev/null | grep -q "$KEY_FINGERPRINT"; then
  exit 0
fi

echo "Importing GPG key from agenix..."
if "$RAGE_BIN" -d -i "$IDENTITY_KEY" -o "$GPG_TEMP_FILE" "$GPG_SECRET_FILE" 2>/dev/null; then
  "$GPG_BIN" --batch --import "$GPG_TEMP_FILE" 2>/dev/null
  rm -f "$GPG_TEMP_FILE"
  echo "GPG key imported successfully"
fi
