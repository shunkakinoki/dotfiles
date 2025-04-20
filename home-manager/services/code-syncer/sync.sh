#!/usr/bin/env bash

# Ensure target directories exist
mkdir -p "/Users/shunkakinoki/Library/Application Support/Cursor/User"
mkdir -p "/Users/shunkakinoki/Library/Application Support/Windsurf/User"

# Function to sync files
sync_settings() {
  if [ -f "/Users/shunkakinoki/Library/Application Support/Code/User/settings.json" ]; then
    cp "/Users/shunkakinoki/Library/Application Support/Code/User/settings.json" "/Users/shunkakinoki/Library/Application Support/Cursor/User/settings.json"
    cp "/Users/shunkakinoki/Library/Application Support/Code/User/settings.json" "/Users/shunkakinoki/Library/Application Support/Windsurf/User/settings.json"
    echo "Settings synced at $(date)"
  else
    echo "VSCode settings.json not found"
  fi
}

# Initial sync
sync_settings

# Watch for changes
fswatch -o "/Users/shunkakinoki/Library/Application Support/Code/User/settings.json" | while read -r; do
  sync_settings
done 
