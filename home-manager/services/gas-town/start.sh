#!/usr/bin/env bash
set -euo pipefail

# Initialize Gas Town if not already set up
if ! gt status >/dev/null 2>&1; then
  gt init
fi

# Add dotfiles rig if not already present
if ! gt rig list 2>/dev/null | grep -q dotfiles; then
  gt rig add dotfiles --adopt
fi

# Start the daemon (blocks - runs dolt+tmux+daemon)
exec gt up
