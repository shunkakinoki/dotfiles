#!/usr/bin/env bash

set -euo pipefail

# Skip if offline
if ! timeout 3 bash -c 'exec 3<>/dev/tcp/1.1.1.1/53' 2>/dev/null; then
  echo "Network unavailable, skipping npm globals install"
  exit 0
fi

# Install npm global packages from package.json using bun
# Reads dependencies from ~/dotfiles/package.json and installs them globally

PACKAGE_JSON="${HOME}/dotfiles/package.json"

# Exit if no package.json exists
if [ ! -f "$PACKAGE_JSON" ]; then
  echo "No ${PACKAGE_JSON} found, skipping npm globals install"
  exit 0
fi

# Check for required tools
if ! command -v bun &>/dev/null; then
  echo "bun not found, skipping npm globals install"
  exit 0
fi

if ! command -v jq &>/dev/null; then
  echo "jq not found, skipping npm globals install"
  exit 0
fi

echo "Installing npm global packages from package.json using bun..."
cd "${HOME}/dotfiles"

# Trust postinstall scripts for packages listed in trustedDependencies before installing
TRUSTED_DEPS=$(jq -r '.trustedDependencies[]?' "$PACKAGE_JSON" 2>/dev/null || true)
if [ -n "$TRUSTED_DEPS" ]; then
  echo "Trusting postinstall scripts for: $TRUSTED_DEPS"
  echo "$TRUSTED_DEPS" | while read -r dep; do
    bun pm -g trust "$dep" 2>/dev/null || true
  done
fi

# Install global packages
DEPS=$(jq -r '.dependencies | keys[]' "$PACKAGE_JSON" 2>/dev/null || true)
if [ -n "$DEPS" ]; then
  # shellcheck disable=SC2086
  bun install --global $DEPS 2>/dev/null || true
fi

# Apply dependency overrides to the global install
# Bun's flat hoisting can resolve incompatible versions (e.g. pino@10 vs pino-http@10.5)
OVERRIDES=$(jq -c '.overrides // empty' "$PACKAGE_JSON" 2>/dev/null || true)
if [ -n "$OVERRIDES" ]; then
  GLOBAL_PKG="${HOME}/.bun/install/global/package.json"
  if [ -f "$GLOBAL_PKG" ]; then
    jq --argjson overrides "$OVERRIDES" '.overrides = $overrides' "$GLOBAL_PKG" >"${GLOBAL_PKG}.tmp" &&
      mv "${GLOBAL_PKG}.tmp" "$GLOBAL_PKG"
    (cd "${HOME}/.bun/install/global" && bun install 2>/dev/null || true)
    echo "Applied dependency overrides to global install"
  fi
fi

echo "npm globals installation complete"
