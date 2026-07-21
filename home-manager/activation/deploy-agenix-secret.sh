#!/usr/bin/env bash
# Decrypt and deploy an agenix secret, replacing the destination when content changes.
# Usage: deploy-agenix-secret.sh <dest_path> <secret_file> <identity_key> <rage_bin>
set -euo pipefail
DEST="$1"
SECRET_FILE="$2"
IDENTITY_KEY="$3"
RAGE_BIN="$4"

if [[ ! -f $SECRET_FILE ]]; then
  echo "Warning: Secret file not found at $SECRET_FILE" >&2
  exit 0
fi

TMP="$(mktemp)"
cleanup() {
  rm -f "$TMP"
}
trap cleanup EXIT

echo "Deploying secret from agenix..."
if ! "$RAGE_BIN" -d -i "$IDENTITY_KEY" "$SECRET_FILE" -o "$TMP" 2>/dev/null; then
  echo "Warning: SSH key not authorized to decrypt - skipping" >&2
  exit 0
fi

chmod 0600 "$TMP"

if [[ -f $DEST ]] && cmp -s "$TMP" "$DEST"; then
  echo "Secret already up to date"
  exit 0
fi

# Atomic replace into the destination directory
DEST_DIR="$(dirname "$DEST")"
mkdir -p "$DEST_DIR"
STAGE="${DEST}.agenix.new"
mv -f "$TMP" "$STAGE"
trap - EXIT
mv -f "$STAGE" "$DEST"
chmod 0600 "$DEST"
echo "Secret deployed successfully"
