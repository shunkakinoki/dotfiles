#!/usr/bin/env bash
# Toggle Ghostty scratchpad terminal

CLASS="ghostty-scratchpad"

if hyprctl clients -j | grep -q "\"class\": \"$CLASS\""; then
  hyprctl dispatch togglespecialworkspace scratchpad
else
  ghostty --class="$CLASS" &
  sleep 0.3
  hyprctl dispatch togglespecialworkspace scratchpad
fi
