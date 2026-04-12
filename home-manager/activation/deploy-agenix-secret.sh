#!/usr/bin/env bash
# Decrypt and deploy an agenix secret if destination doesn't exist
# Usage: deploy-agenix-secret.sh <dest_path> <secret_file> <identity_key> <rage_bin>
set -euo pipefail
DEST="$1"
SECRET_FILE="$2"
IDENTITY_KEY="$3"
RAGE_BIN="$4"

if [[ -f "$DEST" ]]; then
  exit 0
fi

echo "Deploying secret from agenix..."
if [[ ! -f "$SECRET_FILE" ]]; then
  echo "Warning: Secret file not found at $SECRET_FILE" >&2
  exit 0
fi

if "$RAGE_BIN" -d -i "$IDENTITY_KEY" "$SECRET_FILE" -o "$DEST" 2>/dev/null; then
  chmod 0600 "$DEST"
  echo "Secret deployed successfully"
else
  echo "Warning: SSH key not authorized to decrypt - skipping" >&2
fi
