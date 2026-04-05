#!/usr/bin/env bash

set -euo pipefail

# Skip if offline
if ! timeout 3 bash -c 'exec 3<>/dev/tcp/1.1.1.1/53' 2>/dev/null; then
  echo "Network unavailable, skipping uv globals install"
  exit 0
fi

PYPROJECT="${HOME}/dotfiles/pyproject.toml"

if [ ! -f "$PYPROJECT" ]; then
  echo "No ${PYPROJECT} found, skipping uv globals install"
  exit 0
fi

if ! command -v uv &>/dev/null; then
  echo "uv not found, skipping uv globals install"
  exit 0
fi

if ! command -v tomlq &>/dev/null; then
  echo "tomlq not found, skipping uv globals install"
  exit 0
fi

# Install uv global tools from pyproject.toml
# Reads dependencies from ~/dotfiles/pyproject.toml and installs them as global tools
echo "Installing uv global tools from pyproject.toml..."

DEPS=$(tomlq -r '.["dependency-groups"].tools[]' "$PYPROJECT" 2>/dev/null)

if [ -z "$DEPS" ]; then
  echo "No dependencies found in pyproject.toml"
  exit 0
fi

echo "$DEPS" | while read -r pkg; do
  if [ -n "$pkg" ]; then
    echo "Installing $pkg..."
    uv tool install "$pkg" --force 2>/dev/null || echo "Failed to install $pkg, skipping..."
  fi
done

echo "uv globals installation complete"
