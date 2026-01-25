#!/usr/bin/env bash

set -euo pipefail

# Install uv global tools from pyproject.toml
# Reads dependencies from ~/dotfiles/pyproject.toml and installs them as global tools

PYPROJECT="${HOME}/dotfiles/pyproject.toml"

# Exit if no pyproject.toml exists
if [ ! -f "$PYPROJECT" ]; then
  echo "No ${PYPROJECT} found, skipping uv globals install"
  exit 0
fi

# Check for required tools
if ! command -v uv &>/dev/null; then
  echo "uv not found, skipping uv globals install"
  exit 0
fi

if ! command -v dasel &>/dev/null; then
  echo "dasel not found, skipping uv globals install"
  exit 0
fi

if ! command -v jq &>/dev/null; then
  echo "jq not found, skipping uv globals install"
  exit 0
fi

echo "Installing uv global tools from pyproject.toml..."

# Parse Python version from requires-python (e.g., ">=3.13" -> "3.13")
PYTHON_VERSION=$(dasel -f "$PYPROJECT" -r toml 'project.requires-python' 2>/dev/null | sed 's/[^0-9.]//g' || echo "3.13")

# Parse dependencies from standard pyproject.toml format
DEPS=$(dasel -f "$PYPROJECT" -r toml -w json 'project.dependencies' 2>/dev/null | jq -r '.[]' 2>/dev/null || true)

if [ -z "$DEPS" ]; then
  echo "No dependencies found in pyproject.toml"
  exit 0
fi

echo "$DEPS" | while read -r pkg; do
  if [ -n "$pkg" ]; then
    echo "Installing $pkg..."
    # Try default Python first, fall back to version from pyproject.toml
    if ! uv tool install "$pkg" --force 2>/dev/null; then
      if uv tool install "$pkg" --python "$PYTHON_VERSION" --force 2>/dev/null; then
        echo "Installed $pkg with Python $PYTHON_VERSION"
      else
        echo "Failed to install $pkg, skipping..."
      fi
    fi
  fi
done

echo "uv globals installation complete"
