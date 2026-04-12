#!/usr/bin/env bash
# Create Tailscale state and run directories
# Usage: activate-create-dirs.sh <state_dir> <run_dir>
set -euo pipefail
STATE_DIR="$1"
RUN_DIR="$2"

mkdir -p "$STATE_DIR"
mkdir -p "$RUN_DIR"
chmod 700 "$STATE_DIR"
chmod 700 "$RUN_DIR"
