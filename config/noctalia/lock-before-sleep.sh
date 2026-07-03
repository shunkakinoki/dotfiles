#!/usr/bin/env bash
# Lock through Noctalia before systemd lets suspend continue.
set -euo pipefail

NOCTALIA="@noctalia@"
SLEEP="@sleep@"

# v5 IPC surface: `noctalia msg session <lock|...>` (was `ipc call lockScreen lock`).
if ! "$NOCTALIA" msg session lock; then
  exit 0
fi

"$SLEEP" 1
