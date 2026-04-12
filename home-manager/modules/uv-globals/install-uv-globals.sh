#!/usr/bin/env bash

set -euo pipefail

# Skip during boot on Linux (SYSTEMCTL_BIN set by nix activation)
if [ -n "${SYSTEMCTL_BIN:-}" ] && [ "$("$SYSTEMCTL_BIN" is-system-running 2>/dev/null)" = "starting" ]; then
  echo "System is booting, skipping uv globals install"
  exit 0
fi

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

PYTHON_VERSION=$(tomlq -r '.project["requires-python"]' "$PYPROJECT" 2>/dev/null | sed 's/[^0-9.]//g')
PYTHON_VERSION=${PYTHON_VERSION:-3.13}

DEPS=$(tomlq -r '.["dependency-groups"].tools[]' "$PYPROJECT" 2>/dev/null)

if [ -z "$DEPS" ]; then
  echo "No dependencies found in pyproject.toml"
  exit 0
fi

INSTALLED=$(uv tool list 2>/dev/null || true)

echo "$DEPS" | while read -r pkg; do
  if [ -z "$pkg" ]; then
    continue
  fi
  name=${pkg%%[><=!]*}
  # Extract minimum version from spec (e.g. ">=0.86.2" -> "0.86.2")
  req_version=$(echo "$pkg" | sed -n 's/.*>=\([0-9][0-9.]*\).*/\1/p')
  installed_version=$(echo "$INSTALLED" | sed -n "s/^${name} v\([0-9][0-9.]*\).*/\1/p")

  if [ -n "$installed_version" ] && [ -n "$req_version" ]; then
    if printf '%s\n%s\n' "$req_version" "$installed_version" | sort -V | head -n1 | grep -qx "$req_version"; then
      echo "$name $installed_version already installed, skipping"
      continue
    fi
  fi
  echo "Installing $pkg..."
  uv tool install "$pkg" --python "$PYTHON_VERSION" --force 2>/dev/null || echo "Failed to install $pkg, skipping..."
done

echo "uv globals installation complete"
