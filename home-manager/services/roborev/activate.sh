#!/usr/bin/env bash
# Create roborev data directory with correct permissions
# Usage: activate.sh <data_dir>
set -euo pipefail
DATA_DIR="$1"

mkdir -p "$DATA_DIR"
chmod 700 "$DATA_DIR"
