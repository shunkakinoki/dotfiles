#!/usr/bin/env bash

set -euo pipefail

cd ~/dotfiles

# Skip if the current branch is not main
if [ "$(git rev-parse --abbrev-ref HEAD)" != "main" ]; then
  echo "Skipping update as current branch is not main"
  exit 0
fi

# Fetch and pull latest changes
git fetch origin main
git reset --hard origin/main

# Run the install script
./install.sh 
