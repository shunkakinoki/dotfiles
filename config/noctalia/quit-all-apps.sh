#!/usr/bin/env bash
set -euo pipefail
hyprctl clients -j | jq -r '.[].address' | while read -r addr; do
  hyprctl dispatch closewindow "address:$addr"
done
