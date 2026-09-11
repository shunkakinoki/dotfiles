#!/usr/bin/env bash
# Remove stale Home Manager links and backup user-owned files before Home
# Manager checks the targets it is about to link.
set -euo pipefail

while IFS= read -r -d '' link; do
  target=$(readlink -- "$link")
  case "$target" in
  /nix/store/*-home-manager-generation/* | /nix/store/*-home-manager-files/*)
    relative=${link#"$HOME/"}
    echo "Removing stale Home Manager link $relative"
    rm -f -- "$link"
    ;;
  esac
done < <(find "$HOME" -type l -print0)

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
