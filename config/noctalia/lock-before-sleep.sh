#!/usr/bin/env bash
# Start hyprlock before systemd lets suspend continue.
set -euo pipefail

SYSTEMCTL="@systemctl@"
SLEEP="@sleep@"

if ! "$SYSTEMCTL" --user start hyprlock.service; then
  exit 0
fi

"$SLEEP" 1
