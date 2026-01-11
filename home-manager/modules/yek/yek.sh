#!/usr/bin/env bash

set -euo pipefail

INSTALL_DIR="$HOME/.local/bin"
YEK_BIN="${INSTALL_DIR}/yek"

# Install yek if not present
if [ ! -f "${YEK_BIN}" ]; then
    echo "yek not found. Installing latest version..."
    @install_yek@
fi

# Execute yek with all arguments
exec "${YEK_BIN}" "$@"
