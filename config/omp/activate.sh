#!/usr/bin/env bash
# Copy OMP config and set up extension symlink
# Usage: activate.sh <config_yml>
set -euo pipefail
CONFIG_YML="$1"

BUN_GLOBAL_EXTENSION="${BUN_INSTALL:-$HOME/.bun}/install/global/node_modules/@oh-my-pi/swarm-extension"
LOCAL_EXTENSION="$HOME/dotfiles/node_modules/@oh-my-pi/swarm-extension"
if [[ -d "$BUN_GLOBAL_EXTENSION" ]]; then
  SWARM_EXTENSION="$BUN_GLOBAL_EXTENSION"
elif [[ -d "$LOCAL_EXTENSION" ]]; then
  SWARM_EXTENSION="$LOCAL_EXTENSION"
else
  echo "ERROR: @oh-my-pi/swarm-extension is not installed" >&2
  echo "Install it globally or run the dotfiles dependency bootstrap, then retry Home Manager activation." >&2
  exit 1
fi

mkdir -p ~/.omp/agent ~/.omp/agent/extensions
cp -f "$CONFIG_YML" ~/.omp/agent/config.yml
chmod 644 ~/.omp/agent/config.yml
ln -sfn "$SWARM_EXTENSION" ~/.omp/agent/extensions/swarm-extension
