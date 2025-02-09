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
