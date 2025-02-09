#!/usr/bin/env bash

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Define directories
HOME_DIR="$HOME"
CONFIG_DIR="$HOME_DIR/.config"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Helper functions
log() {
    echo -e "${BLUE}🔄 $1${NC}"
}

success() {
    echo -e "${GREEN}✓ $1${NC}"
}

error() {
    echo -e "${RED}❌ $1${NC}"
    exit 1
}

sync_file() {
    local src="$1"
    local dest="$2"
    local name="$3"
    
    if [ ! -f "$dest" ]; then
        cp -f "$src" "$dest"
        success "Synced $name"
    fi
}

create_symlink() {
    local src="$1"
    local dest="$2"
    local name="$3"
    
    if [ ! -L "$dest" ]; then
        ln -sf "$src" "$dest"
        success "Created $name symlink"
    fi
}

# Main script
main() {
    log "Syncing configuration files..."

    # Sync nix configuration
    sync_file "$REPO_ROOT/nix/nix.conf" "$CONFIG_DIR/nix/nix.conf" "nix.conf"

    success "Configuration sync complete"
}

main "$@" 
