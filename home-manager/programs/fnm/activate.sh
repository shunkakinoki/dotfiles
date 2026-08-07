#!/usr/bin/env bash
# shellcheck disable=SC2012
# Pre-install Node.js versions and set default via fnm
# Usage: activate.sh <fnm_bin> <fnm_dir> <default_version> [version1] [version2] ...
set -euo pipefail
FNM_BIN="$1"
FNM_DIR="$2"
DEFAULT_VERSION="$3"
shift 3

export FNM_DIR

# Install each version if not already installed
for version in "$DEFAULT_VERSION" "$@"; do
  if ! ls -d "$FNM_DIR/node-versions/v${version}"* >/dev/null 2>&1; then
    "$FNM_BIN" install "$version" || true
  fi
done

# Set default version
"$FNM_BIN" default "$DEFAULT_VERSION" || true

# Create a stable symlink to the configured default for non-interactive services.
if [ -d "$FNM_DIR/node-versions" ]; then
  default_node=$(ls -d "$FNM_DIR/node-versions/v${DEFAULT_VERSION}"* 2>/dev/null | head -1)
  if [ -n "$default_node" ] && [ -d "$default_node/installation/bin" ]; then
    mkdir -p "$HOME/.local/bin"
    ln -sf "$default_node/installation/bin/node" "$HOME/.local/bin/node"
  fi
fi
