#!/usr/bin/env bash
# Lock through Noctalia before systemd lets suspend continue.
set -euo pipefail

NOCTALIA_SHELL="@noctalia_shell@"
SLEEP="@sleep@"

if ! "$NOCTALIA_SHELL" ipc call lockScreen lock; then
  exit 0
fi

"$SLEEP" 1
