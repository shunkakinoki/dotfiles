#!/usr/bin/env bash

set -euo pipefail

# Install cargo global packages from Cargo.toml
# Reads dependencies from ~/dotfiles/Cargo.toml and installs them globally

CARGO_TOML="${HOME}/dotfiles/Cargo.toml"

# Exit if no Cargo.toml exists
if [ ! -f "$CARGO_TOML" ]; then
  echo "No ${CARGO_TOML} found, skipping cargo globals install"
  exit 0
fi

# Check for required tools
if ! command -v cargo &>/dev/null; then
  echo "cargo not found, skipping cargo globals install"
  exit 0
fi

if ! command -v dasel &>/dev/null; then
  echo "dasel not found, skipping cargo globals install"
  exit 0
fi

if ! command -v jq &>/dev/null; then
  echo "jq not found, skipping cargo globals install"
  exit 0
fi

# Parse dependencies from standard Cargo.toml format
DEPS=$(dasel -f "$CARGO_TOML" -r toml -w json 'dependencies' 2>/dev/null | jq -r 'to_entries[] | "\(.key)@\(.value)"' 2>/dev/null || true)

if [ -z "$DEPS" ]; then
  echo "No dependencies found in Cargo.toml"
  exit 0
fi

# Get currently installed packages (cargo's native cache)
INSTALLED=$(cargo install --list 2>/dev/null || true)

echo "$DEPS" | while read -r pkg; do
  CRATE=$(echo "$pkg" | cut -d'@' -f1)
  VERSION=$(echo "$pkg" | cut -d'@' -f2)
  if [ -n "$CRATE" ]; then
    # Check if already installed at this version (format: "crate_name v1.2.3:")
    if echo "$INSTALLED" | grep -q "^${CRATE} v${VERSION}:"; then
      echo "$CRATE@$VERSION already installed, skipping"
      continue
    fi
    echo "Installing $CRATE@$VERSION..."
    cargo install "$CRATE" --version "$VERSION" --locked 2>/dev/null ||
      cargo install "$CRATE" --version "$VERSION" 2>/dev/null ||
      echo "Failed to install $CRATE@$VERSION, skipping..."
  fi
done

echo "cargo globals check complete"
