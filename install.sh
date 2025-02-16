#!/bin/bash

# Exit on error
set -e

# Detect OS using uname
OS_NAME=$(uname)
case "$OS_NAME" in
Darwin)
  OS="macos"
  ;;
Linux)
  OS="linux"
  ;;
*)
  echo "Unsupported operating system: $OS_NAME"
  exit 1
  ;;
esac

# Install Nix if not already installed
if ! command -v nix >/dev/null 2>&1; then
  echo "Installing Nix..."
  if [ "$OS" = "macos" ]; then
    curl -L https://nixos.org/nix/install | bash
  else
    curl -L https://nixos.org/nix/install | bash -s -- --daemon
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
  cd - >/dev/null
else
  echo "Cloning dotfiles repository into $DOTFILES_DIR..."
  git clone https://github.com/shunkakinoki/dotfiles.git "$DOTFILES_DIR"
  cd "$DOTFILES_DIR"
  git checkout "$COMMIT_REF"
fi

# Install Nix packages
make install
