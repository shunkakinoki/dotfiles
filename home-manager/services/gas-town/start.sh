#!/usr/bin/env bash
set -euo pipefail

GT_TOWN_ROOT="$HOME/ghq/github.com/shunkakinoki/gthq"
cd "$GT_TOWN_ROOT"

# Initialize Gas Town if not already set up
if ! gt status >/dev/null 2>&1; then
  gt init
fi

# Register rigs from mayor/rigs.json
if [ -f mayor/rigs.json ]; then
  existing=$(gt rig list 2>/dev/null || true)
  for rig in $(jq -r '.rigs | keys[]' mayor/rigs.json); do
    if ! echo "$existing" | grep -q "$rig"; then
      gt rig add "$rig" --adopt
    fi
  done
fi

# Start the daemon (blocks - runs dolt+tmux+daemon)
exec gt up
