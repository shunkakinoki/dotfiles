#!/usr/bin/env bash
# Remove stale Home Manager links and backup user-owned files before Home
# Manager checks the targets it is about to link.
set -euo pipefail

home_files=${1:?Home Manager home-files path is required}

# Inspect only paths in the new generation manifest. This avoids traversing
# user data and durable activation snapshots while still replacing links from
# any previous Home Manager generation.
while IFS= read -r -d '' link; do
  target_path=${link#"$home_files/"}
  target="$HOME/$target_path"
  [ -L "$target" ] || continue
  link_target=$(readlink -- "$target")
  case "$link_target" in
  /nix/store/*-home-manager-generation/* | /nix/store/*-home-manager-files/*)
    relative=${target#"$HOME/"}
    echo "Removing stale Home Manager link $relative"
    rm -f -- "$target"
    ;;
  esac
done < <(find -L "$home_files" -type f -print0)

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
