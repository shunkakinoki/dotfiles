#!/usr/bin/env bash
# Backup auth files to R2 before service start
# Protects against race condition deletions

set -euo pipefail

CONFIG_DIR="$HOME/.cli-proxy-api"
BACKUP_DIR="s3://cliproxyapi/backup/auths/"
MAIN_DIR="s3://cliproxyapi/auths/"
AUTH_DIR="$CONFIG_DIR/objectstore/auths"
DOTFILES_AUTH_DIR="$HOME/dotfiles/objectstore/auths"
CCS_AUTH_DIR="$HOME/.ccs/cliproxy/auth"

# STEP 1: Pull from R2 to local (captures files created by cliproxyapi directly in R2)
mkdir -p "$AUTH_DIR"
if [ -n "${OBJECTSTORE_ENDPOINT:-}" ]; then
  AWS_ACCESS_KEY_ID="${OBJECTSTORE_ACCESS_KEY}" \
    AWS_SECRET_ACCESS_KEY="${OBJECTSTORE_SECRET_KEY}" \
    @aws@ s3 sync \
    --endpoint-url="${OBJECTSTORE_ENDPOINT}" \
    --no-progress \
    "$MAIN_DIR" \
    "$AUTH_DIR/" 2>/dev/null && echo "✅ Pulled from R2 auths/" >&2 || true

  # Also pull from backup location to ensure we have all files
  AWS_ACCESS_KEY_ID="${OBJECTSTORE_ACCESS_KEY}" \
    AWS_SECRET_ACCESS_KEY="${OBJECTSTORE_SECRET_KEY}" \
    @aws@ s3 sync \
    --endpoint-url="${OBJECTSTORE_ENDPOINT}" \
    --no-progress \
    "$BACKUP_DIR" \
    "$AUTH_DIR/" 2>/dev/null && echo "✅ Pulled from R2 backup/auths/" >&2 || true
fi

# STEP 2: Merge missing files from dotfiles (macOS only)
# Uses --ignore-existing to never overwrite files from R2, only fill gaps
# This recovers files that may have been deleted from R2 but exist in git
# No circular loop risk since dotfiles is not in WatchPaths
if [ "$(uname)" = "Darwin" ]; then
  if [ -d "$DOTFILES_AUTH_DIR" ] && [ -n "$(ls -A "$DOTFILES_AUTH_DIR" 2>/dev/null)" ]; then
    before_count=$(find "$AUTH_DIR" -maxdepth 1 -type f 2>/dev/null | wc -l | tr -d ' ')
    @rsync@ -a --ignore-existing "$DOTFILES_AUTH_DIR/" "$AUTH_DIR/"
    after_count=$(find "$AUTH_DIR" -maxdepth 1 -type f 2>/dev/null | wc -l | tr -d ' ')
    if [ "$after_count" -gt "$before_count" ]; then
      echo "✅ Recovered $((after_count - before_count)) missing file(s) from dotfiles" >&2
    fi
  fi
fi

# STEP 3: Sync from ccs auth dir (picks up files created by ccs's internal cliproxy)
if [ -d "$CCS_AUTH_DIR" ] && [ -n "$(ls -A "$CCS_AUTH_DIR" 2>/dev/null)" ]; then
  @rsync@ -a "$CCS_AUTH_DIR/" "$AUTH_DIR/"
  echo "✅ Synced from ccs auth dir to local cache" >&2
fi

# Check if auth directory has files
if [ -d "$AUTH_DIR" ] && [ -n "$(ls -A "$AUTH_DIR" 2>/dev/null)" ]; then
  echo "Syncing auth files to R2..." >&2

  # Sync to main auths/ location (what cliproxyapi reads from)
  if [ -z "${OBJECTSTORE_ENDPOINT:-}" ]; then
    echo "⚠️  OBJECTSTORE_ENDPOINT not set, skipping R2 sync" >&2
  else
    AWS_ACCESS_KEY_ID="${OBJECTSTORE_ACCESS_KEY}" \
      AWS_SECRET_ACCESS_KEY="${OBJECTSTORE_SECRET_KEY}" \
      @aws@ s3 sync \
      --endpoint-url="${OBJECTSTORE_ENDPOINT}" \
      --no-progress \
      "$AUTH_DIR/" \
      "$MAIN_DIR" && echo "✅ Synced to auths/" >&2 || echo "⚠️  Sync to auths/ failed: $?" >&2

    # Also sync to backup location for redundancy
    AWS_ACCESS_KEY_ID="${OBJECTSTORE_ACCESS_KEY}" \
      AWS_SECRET_ACCESS_KEY="${OBJECTSTORE_SECRET_KEY}" \
      @aws@ s3 sync \
      --endpoint-url="${OBJECTSTORE_ENDPOINT}" \
      --no-progress \
      "$AUTH_DIR/" \
      "$BACKUP_DIR" && echo "✅ Synced to backup/auths/" >&2 || echo "⚠️  Backup sync failed" >&2
  fi

  # Sync to ccs auth dir (so ccs can find the tokens)
  mkdir -p "$CCS_AUTH_DIR"
  @rsync@ -a "$AUTH_DIR/" "$CCS_AUTH_DIR/"
  echo "✅ Synced to ccs auth dir" >&2

  # macOS only: Sync back to dotfiles repo for git tracking
  # (Skipped on Linux to avoid redundant auth file copies)
  if [ "$(uname)" = "Darwin" ]; then
    mkdir -p "$DOTFILES_AUTH_DIR"
    @rsync@ -a "$AUTH_DIR/" "$DOTFILES_AUTH_DIR/"
    echo "✅ Synced to dotfiles repo" >&2
  fi
fi
