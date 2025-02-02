#!/bin/bash
set -e

# Special handling for Codespaces
if [ -n "$CODESPACES" ]; then
  echo "❗ Using shared Codespaces dotfiles path"
  ln -sf "$dotfiles_dir" "$HOME/dotfiles"
fi

# Main symlink logic will go here
