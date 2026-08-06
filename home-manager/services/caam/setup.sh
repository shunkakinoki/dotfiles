#!/usr/bin/env bash
# Idempotent CAAM sync pool bootstrap for every host:
# discover peers from ~/.ssh/config, add them to the pool, enable auto-sync.
set -euo pipefail

CAAM="${CAAM:-$HOME/.local/bin/caam}"

if [[ ! -x $CAAM ]]; then
  echo "caam not found at $CAAM; skipping sync setup" >&2
  exit 0
fi

export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin${PATH:+:$PATH}"

echo "Discovering CAAM sync peers from SSH config..."
"$CAAM" sync discover --add || true

# Local hosts are useless in a multi-machine pool; drop them if discovery
# added localhost, the full hostname, or its short form from SSH config.
"$CAAM" sync remove localhost --force >/dev/null 2>&1 || true

local_hostname="$(hostname 2>/dev/null || true)"
local_short_hostname="${local_hostname%%.*}"

if [[ -n $local_hostname && $local_hostname != "localhost" ]]; then
  "$CAAM" sync remove "$local_hostname" --force >/dev/null 2>&1 || true
fi

if [[ 
  -n $local_short_hostname &&
  $local_short_hostname != "localhost" &&
  $local_short_hostname != "$local_hostname" ]] \
  ; then
  "$CAAM" sync remove "$local_short_hostname" --force >/dev/null 2>&1 || true
fi

echo "Enabling CAAM auto-sync after backup/refresh..."
"$CAAM" sync enable

"$CAAM" sync status || true
