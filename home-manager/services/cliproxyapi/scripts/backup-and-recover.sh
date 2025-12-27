#!/usr/bin/env bash
# Combined backup and recovery script
# Backs up auth files to R2, then recovers if missing

set -euo pipefail

# Source .env for credentials
if [ -f "$HOME/dotfiles/.env" ]; then
  set -a
  # shellcheck source=/dev/null
  source "$HOME/dotfiles/.env"
  set +a
fi

# Run backup
echo "[$(date)] Starting backup..."
@backupAuthScript@

# Run recovery if needed
echo "[$(date)] Checking for recovery..."
@recoverAuthScript@

echo "[$(date)] Backup/recovery cycle complete"
