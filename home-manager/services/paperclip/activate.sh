#!/usr/bin/env bash
# Create Paperclip directories with correct permissions
# Usage: activate.sh <home_dir>
set -euo pipefail
HOME_DIR="$1"

mkdir -p /tmp/paperclip
mkdir -p "$HOME_DIR/.paperclip"
chmod 700 "$HOME_DIR/.paperclip"
