#!/usr/bin/env bash
# Combined backup and recovery script
# Backs up auth files to R2, then recovers if missing

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source .env for credentials
if [ -f "$HOME/dotfiles/.env" ]; then
  set -a
  # shellcheck source=/dev/null
  source "$HOME/dotfiles/.env"
  set +a
fi

# Run backup
echo "[$(date)] Starting backup..."
"$SCRIPT_DIR/backup-auth.sh"

# Run recovery if needed
echo "[$(date)] Checking for recovery..."
"$SCRIPT_DIR/recover-auth.sh"

echo "[$(date)] Backup/recovery cycle complete"
