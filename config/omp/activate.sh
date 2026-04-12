#!/usr/bin/env bash
# Copy OMP config and set up extension symlink
# Usage: activate.sh <config_yml>
set -euo pipefail
CONFIG_YML="$1"

mkdir -p ~/.omp/agent ~/.omp/agent/extensions
cp -f "$CONFIG_YML" ~/.omp/agent/config.yml
chmod 644 ~/.omp/agent/config.yml
ln -sfn "$HOME/dotfiles/node_modules/@oh-my-pi/swarm-extension" ~/.omp/agent/extensions/swarm-extension
