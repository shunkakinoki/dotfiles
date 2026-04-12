#!/usr/bin/env bash
# Create directories with specified permissions
# Usage: ensure-directory.sh <mode> <dir1> [dir2...]
set -euo pipefail
MODE="$1"
shift
for DIR in "$@"; do
  mkdir -p "$DIR"
  chmod "$MODE" "$DIR"
done
