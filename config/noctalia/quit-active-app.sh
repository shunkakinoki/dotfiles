#!/usr/bin/env bash
set -euo pipefail
class=$(hyprctl activewindow -j | jq -r '.class')
if [ -z "$class" ] || [ "$class" = "null" ]; then
  exit 0
fi
hyprctl clients -j | jq -r --arg c "$class" '.[] | select(.class == $c) | .address' | while read -r addr; do
  hyprctl dispatch closewindow "address:$addr"
done
