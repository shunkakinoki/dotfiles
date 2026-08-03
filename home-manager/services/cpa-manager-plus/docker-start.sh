#!/usr/bin/env bash
set -euo pipefail

SCRIPT="@bash@/bin/bash @start_script@"

if @docker@ info >/dev/null 2>&1; then
  exec $SCRIPT
fi

if [ -x /run/wrappers/bin/sg ]; then
  exec /run/wrappers/bin/sg docker -c "$SCRIPT"
elif [ -x /usr/bin/sg ]; then
  exec /usr/bin/sg docker -c "$SCRIPT"
else
  echo "ERROR: Cannot access Docker. User not in docker group and no sg binary found." >&2
  exit 1
fi
