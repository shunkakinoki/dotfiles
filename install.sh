#!/usr/bin/env bash

# Exit on error
set -e

# Detect OS
if [[ $OSTYPE == "darwin"* ]]; then
  OS="macos"
elif [[ $OSTYPE == "linux-gnu"* ]]; then
  OS="linux"
else
  echo "Unsupported operating system: $OSTYPE"
  exit 1
fi

# Install Nix if not already installed
if ! command -v nix &>/dev/null; then
  echo "Installing Nix..."
  if [[ $OS == "macos" ]]; then
    sh <(curl -L https://nixos.org/nix/install) --daemon
  else
    sh <(curl -L https://nixos.org/nix/install) --daemon
  fi
fi

# Determine the commit reference:
# If GITHUB_SHA is set then use it; otherwise, default to "main"
COMMIT_REF="${GITHUB_SHA:-main}"
echo "Using commit reference: $COMMIT_REF"

DOTFILES_DIR="$HOME/dotfiles"
echo "Fetching the dotfiles repository..."

if [ -d "$DOTFILES_DIR" ]; then
  echo "Dotfiles repository already exists. Fetching latest changes and checking out $COMMIT_REF..."
  cd "$DOTFILES_DIR"
  git fetch origin
  git checkout "$COMMIT_REF"
  git pull
  cd - > /dev/null
else
  echo "Cloning dotfiles repository into $DOTFILES_DIR..."
  git clone https://github.com/shunkakinoki/dotfiles.git "$DOTFILES_DIR"
  cd "$DOTFILES_DIR"
  git checkout "$COMMIT_REF"
fi

# Install Nix packages
make install
