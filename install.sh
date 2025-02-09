#!/usr/bin/env bash

# Exit on error
set -e

# Detect OS
if [[ "$OSTYPE" == "darwin"* ]]; then
    OS="macos"
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    OS="linux"
else
    echo "Unsupported operating system: $OSTYPE"
    exit 1
fi

# Install Nix if not already installed
if ! command -v nix &> /dev/null; then
    echo "Installing Nix..."
    if [[ "$OS" == "macos" ]]; then
        sh <(curl -L https://nixos.org/nix/install) --daemon
    else
        sh <(curl -L https://nixos.org/nix/install) --daemon
    fi
    
    # Source nix
    . ~/.nix-profile/etc/profile.d/nix.sh
fi

# Install Home Manager if not already installed
if ! command -v home-manager &> /dev/null; then
    echo "Installing Home Manager..."
    nix-channel --add https://github.com/nix-community/home-manager/archive/release-23.11.tar.gz home-manager
    nix-channel --update
    nix run home-manager/archive/release-23.11.tar.gz -- install
fi

# Link Nix configuration
echo "Linking Nix configuration..."

# Create necessary directories
mkdir -p ~/.config/nixpkgs

# Backup existing configuration if it exists
if [ -f ~/.config/nixpkgs/home.nix ]; then
    echo "Backing up existing home.nix..."
    mv ~/.config/nixpkgs/home.nix ~/.config/nixpkgs/home.nix.backup
fi

# Link the dotfiles version to system
ln -sf "$(pwd)/dotfiles/nix/home.nix" ~/.config/nixpkgs/home.nix

# Apply configuration
echo "Applying Home Manager configuration..."
home-manager switch

echo "Installation complete! 🎉"
echo "Your development environment has been set up using Nix Home Manager."
