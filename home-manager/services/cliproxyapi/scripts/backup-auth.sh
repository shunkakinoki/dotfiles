#!/usr/bin/env bash
# Backup auth files to R2 before service start
# Protects against race condition deletions

set -euo pipefail

CONFIG_DIR="$HOME/.cli-proxy-api"
BACKUP_DIR="s3://cliproxyapi/backup/auths/"
MAIN_DIR="s3://cliproxyapi/auths/"
AUTH_DIR="$CONFIG_DIR/objectstore/auths"
DOTFILES_AUTH_DIR="$HOME/dotfiles/objectstore/auths"

# STEP 1: Pull from R2 to local (captures files created by cliproxyapi directly in R2)
mkdir -p "$AUTH_DIR"
AWS_ACCESS_KEY_ID="${OBJECTSTORE_ACCESS_KEY}" \
  AWS_SECRET_ACCESS_KEY="${OBJECTSTORE_SECRET_KEY}" \
  aws s3 sync \
  --endpoint-url="${OBJECTSTORE_ENDPOINT}" \
  --no-progress \
  "$MAIN_DIR" \
  "$AUTH_DIR/" 2>/dev/null && echo "✅ Pulled from R2 auths/" >&2 || true

# Also pull from backup location to ensure we have all files
AWS_ACCESS_KEY_ID="${OBJECTSTORE_ACCESS_KEY}" \
  AWS_SECRET_ACCESS_KEY="${OBJECTSTORE_SECRET_KEY}" \
  aws s3 sync \
  --endpoint-url="${OBJECTSTORE_ENDPOINT}" \
  --no-progress \
  "$BACKUP_DIR" \
  "$AUTH_DIR/" 2>/dev/null && echo "✅ Pulled from R2 backup/auths/" >&2 || true

# STEP 2: Sync from dotfiles repo to local cache (picks up new auth files from ccs auth)
if [ -d "$DOTFILES_AUTH_DIR" ] && [ -n "$(ls -A "$DOTFILES_AUTH_DIR" 2>/dev/null)" ]; then
  rsync -a "$DOTFILES_AUTH_DIR/" "$AUTH_DIR/"
  echo "✅ Synced from dotfiles repo to local cache" >&2
fi

# Check if auth directory has files
if [ -d "$AUTH_DIR" ] && [ -n "$(ls -A "$AUTH_DIR" 2>/dev/null)" ]; then
  echo "Syncing auth files to R2..." >&2

  # Sync to main auths/ location (what cliproxyapi reads from)
  AWS_ACCESS_KEY_ID="${OBJECTSTORE_ACCESS_KEY}" \
    AWS_SECRET_ACCESS_KEY="${OBJECTSTORE_SECRET_KEY}" \
    aws s3 sync \
    --endpoint-url="${OBJECTSTORE_ENDPOINT}" \
    --no-progress \
    "$AUTH_DIR/" \
    "$MAIN_DIR" 2>/dev/null && echo "✅ Synced to auths/" >&2 || echo "⚠️  Sync to auths/ failed" >&2

  # Also sync to backup location for redundancy
  AWS_ACCESS_KEY_ID="${OBJECTSTORE_ACCESS_KEY}" \
    AWS_SECRET_ACCESS_KEY="${OBJECTSTORE_SECRET_KEY}" \
    aws s3 sync \
    --endpoint-url="${OBJECTSTORE_ENDPOINT}" \
    --no-progress \
    "$AUTH_DIR/" \
    "$BACKUP_DIR" 2>/dev/null && echo "✅ Synced to backup/auths/" >&2 || echo "⚠️  Backup sync failed" >&2
fi
