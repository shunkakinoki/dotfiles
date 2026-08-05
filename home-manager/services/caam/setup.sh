#!/usr/bin/env bash
# Idempotent CAAM sync pool bootstrap for every host:
# discover peers from ~/.ssh/config, add them to the pool, enable auto-sync.
set -euo pipefail

CAAM="${CAAM:-$HOME/.local/bin/caam}"

if [[ ! -x "$CAAM" ]]; then
  echo "caam not found at $CAAM; skipping sync setup" >&2
  exit 0
fi

export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin${PATH:+:$PATH}"

echo "Discovering CAAM sync peers from SSH config..."
"$CAAM" sync discover --add || true

# localhost is useless in a multi-machine pool; drop it if discover added it.
"$CAAM" sync remove localhost >/dev/null 2>&1 || true

echo "Enabling CAAM auto-sync after backup/refresh..."
"$CAAM" sync enable

"$CAAM" sync status || true
