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

# If GITHUB_PR is set, handle checkout for the PR branch
if [ -n "$GITHUB_PR" ]; then
  echo "Detected PR environment variable GITHUB_PR=$GITHUB_PR"
  PR_REF="refs/pull/${GITHUB_PR}/head"
  echo "Fetching pull request ref: $PR_REF"

  if [ -d "$DOTFILES_DIR" ]; then
    echo "Dotfiles repository already exists. Using git fetch to retrieve PR ref..."
    cd "$DOTFILES_DIR"
    git fetch origin "$PR_REF":pr-"$GITHUB_PR"
    git checkout pr-"$GITHUB_PR"
    git pull
  else
    echo "Cloning dotfiles repository..."
    git clone https://github.com/shunkakinoki/dotfiles.git "$DOTFILES_DIR"
    cd "$DOTFILES_DIR"
    git fetch origin "$PR_REF":pr-"$GITHUB_PR"
    git checkout pr-"$GITHUB_PR"
  fi
else
  COMMIT_REF="${GITHUB_SHA:-main}"
  echo "Using commit reference: $COMMIT_REF"

  if [ -d "$DOTFILES_DIR" ]; then
    echo "Dotfiles repository already exists. Fetching latest changes..."
    cd "$DOTFILES_DIR"
    git fetch origin
    git checkout "$COMMIT_REF"
    git pull
  else
    echo "Cloning dotfiles repository into $DOTFILES_DIR..."
    git clone https://github.com/shunkakinoki/dotfiles.git "$DOTFILES_DIR"
    cd "$DOTFILES_DIR"
    git checkout "$COMMIT_REF"
  fi
fi

# Install Nix packages
make install
