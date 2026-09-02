#!/usr/bin/env bash
# Start the transient hyprlock unit before systemd lets suspend continue.
set -euo pipefail

LOCK_SCREEN="@lockScreen@"
SLEEP="@sleep@"

if ! "$LOCK_SCREEN"; then
  exit 0
fi

"$SLEEP" 1
