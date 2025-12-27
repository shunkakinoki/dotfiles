#!/usr/bin/env bash
# Backup auth files to R2 (pull-first ensures recovery is handled)

set -euo pipefail

# Source .env for credentials
if [ -f "$HOME/dotfiles/.env" ]; then
  set -a
  # shellcheck source=/dev/null
  source "$HOME/dotfiles/.env"
  set +a
fi

# Run backup (handles recovery via pull-first)
echo "[$(date)] Starting backup..."
@bash@ @backupAuthScript@

echo "[$(date)] Backup complete"
