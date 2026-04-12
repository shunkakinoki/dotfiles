#!/usr/bin/env bash
# Backup existing configuration files before home-manager links
set -euo pipefail

for file in .bashrc .profile .bash_profile; do
  if [ -f "$HOME/$file" ] && [ ! -L "$HOME/$file" ]; then
    echo "Backing up existing $file to $file.hm-backup"
    mv "$HOME/$file" "$HOME/$file.hm-backup"
  fi
done

if [ -f "$HOME/.openclaw/openclaw.json" ] && [ ! -L "$HOME/.openclaw/openclaw.json" ]; then
  echo "Backing up existing .openclaw/openclaw.json to .openclaw/openclaw.json.hm-backup"
  mv "$HOME/.openclaw/openclaw.json" "$HOME/.openclaw/openclaw.json.hm-backup"
fi

find ~/.codex -name "*.hm-backup*" -delete 2>/dev/null || true
